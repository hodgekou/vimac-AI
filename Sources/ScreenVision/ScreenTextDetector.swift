// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
@preconcurrency import ScreenCaptureKit
import Vision

/// A piece of text found in a screenshot. `frame` uses accessibility coordinates.
public struct TextRegion: Sendable, Equatable {
    public let text: String
    public let frame: CGRect

    public init(text: String, frame: CGRect) {
        self.text = text
        self.frame = frame
    }
}

/// Finds text in a window by looking at its pixels. Everything runs on the device,
/// and the screenshot only ever exists in memory.
public enum ScreenTextDetector {
    /// Whether this process may capture the screen.
    public static var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Asks the system to show its Screen Recording prompt. Returns whether access is granted now.
    @discardableResult
    public static func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    /// Recognises the text in the window of `pid` whose frame is `windowFrame`.
    /// Returns nothing when that window cannot be found.
    public static func textRegions(pid: pid_t, windowFrame: CGRect) async throws -> [TextRegion] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard
            let window = content.windows.first(where: {
                $0.owningApplication?.processID == pid && isSame($0.frame, windowFrame)
            })
        else { return [] }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let scale = CGFloat(filter.pointPixelScale)
        let configuration = SCStreamConfiguration()
        configuration.width = Int(window.frame.width * scale)
        configuration.height = Int(window.frame.height * scale)
        configuration.showsCursor = false
        // Without this the image is padded by the window shadow and no longer maps onto the frame.
        configuration.ignoreShadowsSingleWindow = true

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        return try recognize(image, windowFrame: window.frame)
    }

    /// Screen coordinates from the two APIs can differ by a fraction of a point.
    private static func isSame(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 4 && abs(a.minY - b.minY) < 4
            && abs(a.width - b.width) < 4 && abs(a.height - b.height) < 4
    }

    private static func recognize(_ image: CGImage, windowFrame: CGRect) throws -> [TextRegion] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])

        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return TextRegion(
                text: candidate.string,
                frame: frame(of: observation.boundingBox, in: windowFrame)
            )
        }
    }

    /// Vision reports boxes in unit coordinates with the origin at the bottom-left of the image.
    static func frame(of box: CGRect, in windowFrame: CGRect) -> CGRect {
        CGRect(
            x: windowFrame.minX + box.minX * windowFrame.width,
            y: windowFrame.minY + (1 - box.maxY) * windowFrame.height,
            width: box.width * windowFrame.width,
            height: box.height * windowFrame.height
        )
    }
}
