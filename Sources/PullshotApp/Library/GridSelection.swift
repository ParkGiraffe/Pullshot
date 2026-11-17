import Foundation
import PullshotKit

struct GridSelection: Equatable {
    enum Click {
        case only, toggle, extend
    }

    enum Move {
        case left, right, up, down
    }

    private(set) var selected: Set<Capture.ID> = []
    private(set) var anchor: Capture.ID?

    mutating func click(_ id: Capture.ID, _ click: Click, in order: [Capture.ID]) {
        switch click {
        case .only:
            selected = [id]
            anchor = id
        case .toggle:
            if selected.contains(id) {
                selected.remove(id)
            } else {
                selected.insert(id)
            }
            anchor = id
        case .extend:
            guard let anchor, let start = order.firstIndex(of: anchor), let end = order.firstIndex(of: id) else {
                self.click(id, .only, in: order)
                return
            }
            selected.formUnion(order[min(start, end) ... max(start, end)])
        }
    }

    mutating func move(_ move: Move, columns: Int, in order: [Capture.ID]) {
        guard let anchor, let current = order.firstIndex(of: anchor) else {
            if let first = order.first {
                click(first, .only, in: order)
            }
            return
        }
        let step = switch move {
        case .left: -1
        case .right: 1
        case .up: -columns
        case .down: columns
        }
        click(order[min(max(current + step, 0), order.count - 1)], .only, in: order)
    }

    mutating func selectAll(_ order: [Capture.ID]) {
        selected = Set(order)
    }

    mutating func clear() {
        selected = []
        anchor = nil
    }

    mutating func keep(_ order: [Capture.ID]) {
        let visible = Set(order)
        selected.formIntersection(visible)
        if let anchor, !visible.contains(anchor) {
            self.anchor = nil
        }
    }

    func previewTargets(in order: [Capture]) -> [Capture] {
        guard let anchor, let current = order.firstIndex(where: { $0.id == anchor }) else { return [] }
        let neighbors = [current + 1, current - 1].filter { order.indices.contains($0) && order[$0].kind == .photo }
        return ([current] + neighbors).map { order[$0] }
    }

    static func columns(width: CGFloat, minimum: CGFloat, spacing: CGFloat) -> Int {
        max(1, Int((width + spacing) / (minimum + spacing)))
    }
}
