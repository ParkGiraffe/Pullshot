import AppKit

enum PreviewKey: Equatable {
    case move(GridSelection.Move)
    case close

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
