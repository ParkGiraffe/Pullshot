import Foundation
import PullshotKit

/// 격자에서 고른 캡처와 기준 캡처입니다. 순서는 격자에 보이는 순서를 받습니다.
struct GridSelection: Equatable {
    /// 그냥 누르기, ⌘를 누른 채 누르기, ⇧를 누른 채 누르기입니다.
    enum Click {
        case only, toggle, extend
    }

    enum Move {
        case left, right, up, down
    }

    private(set) var selected: Set<Capture.ID> = []
    /// 마지막으로 그냥 누르거나 ⌘를 누른 채 누른 캡처입니다. ⇧ 누르기는 기준을 바꾸지 않습니다(Finder와 같음).
    /// ⇧ 누르기, 화살표, 미리보기가 여기서 출발합니다.
    private(set) var anchor: Capture.ID?

    /// `extend`는 기준이 없거나 보이는 순서에 없으면 `only`처럼 합니다.
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

    /// 왼쪽과 오른쪽은 한 칸, 위와 아래는 한 줄 옮겨 하나만 고릅니다. 끝을 넘으면 첫 캡처나 마지막 캡처에서 멈추고,
    /// 기준이 없으면 첫 캡처를 고릅니다.
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

    /// 보이지 않게 된 캡처를 고른 것에서 뺍니다. 기준이 빠지면 기준도 지웁니다.
    mutating func keep(_ order: [Capture.ID]) {
        let visible = Set(order)
        selected.formIntersection(visible)
        if let anchor, !visible.contains(anchor) {
            self.anchor = nil
        }
    }

    /// `LazyVGrid`의 `.adaptive(minimum:)`이 놓는 열 수와 같은 식입니다.
    static func columns(width: CGFloat, minimum: CGFloat, spacing: CGFloat) -> Int {
        max(1, Int((width + spacing) / (minimum + spacing)))
    }
}
