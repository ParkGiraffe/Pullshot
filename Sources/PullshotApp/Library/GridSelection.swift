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

    mutating func move(_ move: Move, in rows: [[Capture.ID]]) {
        let order = rows.flatMap(\.self)
        guard let anchor,
              let row = rows.firstIndex(where: { $0.contains(anchor) }),
              let column = rows[row].firstIndex(of: anchor),
              let current = order.firstIndex(of: anchor)
        else {
            if let first = order.first {
                click(first, .only, in: order)
            }
            return
        }
        let target = switch move {
        case .left: order[max(current - 1, 0)]
        case .right: order[min(current + 1, order.count - 1)]
        case .up: Self.cell(in: rows[max(row - 1, 0)], column: column)
        case .down: Self.cell(in: rows[min(row + 1, rows.count - 1)], column: column)
        }
        click(target, .only, in: order)
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

    private static func cell(in row: [Capture.ID], column: Int) -> Capture.ID {
        row[min(column, row.count - 1)]
    }
}
