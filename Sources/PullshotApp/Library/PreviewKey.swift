import AppKit

/// 미리보기 패널에서 누른 키가 하는 일입니다.
enum PreviewKey: Equatable {
    case move(GridSelection.Move)
    case close

    /// 화살표는 격자처럼 옮기고, 스페이스와 Esc는 Finder처럼 닫습니다. ⌘, ⌥, ⌃, ⇧를 함께 누른 키와 다른 키는
    /// 패널에 맡깁니다.
    init?(_ event: NSEvent) {
        guard event.type == .keyDown, event.modifierFlags.isDisjoint(with: [.command, .option, .control, .shift]) else {
            return nil
        }
        switch event.specialKey {
        case .leftArrow?: self = .move(.left)
        case .rightArrow?: self = .move(.right)
        case .upArrow?: self = .move(.up)
        case .downArrow?: self = .move(.down)
        default:
            guard [" ", "\u{1B}"].contains(event.charactersIgnoringModifiers) else { return nil }
            self = .close
        }
    }
}
