// The traversal strategies are derived from TraverseGenericElementService.swift and
// TraverseSearchPredicateCompatibleWebAreaElementService.swift in Vimac
// (https://github.com/nchudleigh/vimac), Copyright © 2020 Dexter Leng, licensed under GPL-3.0.

import ApplicationServices
import VimacCore

/// Walks the accessibility tree below one root and records every visible node.
final class TreeTraversal {
    struct Node {
        let role: String
        let frame: CGRect
        let clippedFrame: CGRect
        let actions: [String]
        let searchText: String
        var children: [Int] = []
    }

    private(set) var nodes: [Node] = []
    private var visited = Set<AXElement>()
    private var budget: Int

    private static let attributes = [
        kAXRoleAttribute, kAXPositionAttribute, kAXSizeAttribute,
        kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute,
        kAXChildrenAttribute, kAXVisibleRowsAttribute,
    ]

    private static let searchPredicateAttribute = "AXUIElementsForSearchPredicate"
    private static let searchCountAttribute = "AXUIElementCountForSearchPredicate"
    private static let searchKeys = [
        "AXButtonSearchKey", "AXCheckBoxSearchKey", "AXControlSearchKey", "AXGraphicSearchKey",
        "AXLinkSearchKey", "AXRadioGroupSearchKey", "AXTextFieldSearchKey",
    ]

    /// `budget` caps how many nodes are visited, so a huge or cyclic tree cannot stall activation.
    init(budget: Int) {
        self.budget = budget
    }

    /// Visits `element` and its descendants. Returns the node index, or nil when the element
    /// is invisible, already visited, or the budget ran out.
    @discardableResult
    func visit(_ element: AXElement, clip: CGRect?) throws -> Int? {
        try Task.checkCancellation()
        guard budget > 0, visited.insert(element).inserted else { return nil }
        budget -= 1

        let values = element.values(of: Self.attributes)
        guard let role = values[0] as? String,
              let frame = AXDecode.frame(position: values[1], size: values[2]) else { return nil }

        let clipped: CGRect
        if let clip {
            guard clip.intersects(frame) else { return nil }
            clipped = clip.intersection(frame)
        } else {
            clipped = frame
        }

        let index = nodes.count
        nodes.append(Node(
            role: role,
            frame: frame,
            clippedFrame: clipped,
            actions: element.actionNames(),
            searchText: AXDecode.searchText([values[3], values[4], values[5]])
        ))

        if role == "AXWebArea", element.parameterizedAttributeNames().contains(Self.searchPredicateAttribute) {
            // Browsers answer one search far faster than a node-by-node walk, and walking
            // Chromium node by node can trip its accessibility self-protection.
            for child in webAreaDescendants(of: element) {
                if let childIndex = try visitLeaf(child, clip: clipped) {
                    nodes[index].children.append(childIndex)
                }
            }
            return index
        }

        // Tables report every row as a child, including the thousands scrolled out of view.
        let usesVisibleRows = role == "AXTable" || role == "AXOutline"
        let children = AXDecode.elements(usesVisibleRows ? (values[7] ?? values[6]) : values[6])
        for child in children {
            if let childIndex = try visit(child, clip: clipped) {
                nodes[index].children.append(childIndex)
            }
        }
        return index
    }

    /// Records an element without descending into it.
    private func visitLeaf(_ element: AXElement, clip: CGRect) throws -> Int? {
        try Task.checkCancellation()
        guard budget > 0, visited.insert(element).inserted else { return nil }
        budget -= 1

        let values = element.values(of: Array(Self.attributes.prefix(6)))
        guard let role = values[0] as? String,
              let frame = AXDecode.frame(position: values[1], size: values[2]),
              clip.intersects(frame) else { return nil }

        nodes.append(Node(
            role: role,
            frame: frame,
            clippedFrame: clip.intersection(frame),
            actions: element.actionNames(),
            searchText: AXDecode.searchText([values[3], values[4], values[5]])
        ))
        return nodes.count - 1
    }

    private func webAreaDescendants(of webArea: AXElement) -> [AXElement] {
        var query: [String: Any] = [
            "AXDirection": "AXDirectionNext",
            "AXImmediateDescendantsOnly": false,
            "AXResultsLimit": -1,
            "AXVisibleOnly": true,
            "AXSearchKey": Self.searchKeys,
        ]

        // WebKit and current Chromium accept all keys in one request.
        let count = webArea.parameterizedValue(of: Self.searchCountAttribute, parameter: query as CFDictionary) as? Int ?? 0
        if count > 0 {
            return AXDecode.elements(
                webArea.parameterizedValue(of: Self.searchPredicateAttribute, parameter: query as CFDictionary)
            )
        }

        // Older Chromium only understands one key per request.
        var seen = Set<AXElement>()
        var result: [AXElement] = []
        for key in Self.searchKeys {
            query["AXSearchKey"] = key
            let found = AXDecode.elements(
                webArea.parameterizedValue(of: Self.searchPredicateAttribute, parameter: query as CFDictionary)
            )
            for element in found where seen.insert(element).inserted {
                result.append(element)
            }
        }
        return result
    }

    /// The nodes that should get a label.
    func hintableSnapshots(root: Int, source: ElementSource) -> [ElementSnapshot] {
        Hintability.hintableIndices(
            roles: nodes.map(\.role),
            actions: nodes.map(\.actions),
            children: nodes.map(\.children),
            root: root
        ).map { index in
            let node = nodes[index]
            return ElementSnapshot(
                role: node.role,
                frame: node.frame,
                clippedFrame: node.clippedFrame,
                actions: node.actions,
                searchText: node.searchText,
                source: source
            )
        }
    }
}
