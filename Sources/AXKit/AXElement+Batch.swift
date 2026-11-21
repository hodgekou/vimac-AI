// SPDX-License-Identifier: GPL-3.0-only

import ApplicationServices

extension AXElement {
    /// Reads several attributes in one cross-process request.
    /// The result has one entry per requested attribute; missing or failed ones are nil.
    public func values(of attributes: [String]) -> [CFTypeRef?] {
        var result: CFArray?
        let error = AXUIElementCopyMultipleAttributeValues(
            raw, attributes as CFArray, AXCopyMultipleAttributeOptions(rawValue: 0), &result
        )
        guard error == .success, let values = result as? [AnyObject], values.count == attributes.count else {
            return [CFTypeRef?](repeating: nil, count: attributes.count)
        }
        return values.map { value in
            // A failed attribute comes back as an AXValue that wraps the error code.
            if CFGetTypeID(value) == AXValueGetTypeID(),
                AXValueGetType(unsafeDowncast(value, to: AXValue.self)) == .axError
            {
                return nil
            }
            if CFGetTypeID(value) == CFNullGetTypeID() { return nil }
            return value
        }
    }

    public func actionNames() -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(raw, &names) == .success else { return [] }
        return names as? [String] ?? []
    }

    public func parameterizedAttributeNames() -> [String] {
        var names: CFArray?
        guard AXUIElementCopyParameterizedAttributeNames(raw, &names) == .success else { return [] }
        return names as? [String] ?? []
    }

    public func parameterizedValue(of attribute: String, parameter: CFTypeRef) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(raw, attribute as CFString, parameter, &value) == .success else {
            return nil
        }
        return value
    }

    /// Sets a boolean attribute. Returns whether the application accepted it.
    @discardableResult
    public func setBool(_ value: Bool, for attribute: String) -> Bool {
        AXUIElementSetAttributeValue(raw, attribute as CFString, value as CFBoolean) == .success
    }
}

/// Decoders for the raw values returned by accessibility requests.
enum AXDecode {
    static func point(_ value: CFTypeRef?) -> CGPoint? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(unsafeDowncast(value, to: AXValue.self), .cgPoint, &point) ? point : nil
    }

    static func size(_ value: CFTypeRef?) -> CGSize? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(unsafeDowncast(value, to: AXValue.self), .cgSize, &size) ? size : nil
    }

    static func frame(position: CFTypeRef?, size: CFTypeRef?) -> CGRect? {
        guard let origin = point(position), let size = self.size(size) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    static func elements(_ value: CFTypeRef?) -> [AXElement] {
        guard let array = value as? [AnyObject] else { return [] }
        return
            array
            .filter { CFGetTypeID($0) == AXUIElementGetTypeID() }
            .map { AXElement(unsafeDowncast($0, to: AXUIElement.self)) }
    }

    /// Joins the textual attributes into the text that search mode matches against.
    static func searchText(_ values: [CFTypeRef?]) -> String {
        values
            .compactMap { $0 as? String }
            .map { String($0.prefix(100)) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
