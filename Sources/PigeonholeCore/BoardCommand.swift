import AppKit
import Carbon.HIToolbox

/// What a key press on the board means.
public enum BoardCommand: Equatable {
    case move(CursorMove)
    case open
    case copy
    case hide
    case undoHide
    case switchTab
    case showTab(BoardTab)
    case nextOwner
    case nextTag
    case clearFilters
    case refresh
    case openSettings
    case showShortcuts

    public init?(event: NSEvent) {
        self.init(
            keyCode: Int(event.keyCode),
            modifiers: event.modifierFlags,
            characters: event.charactersIgnoringModifiers
        )
    }

    /// Nil for anything held with ⌘, ⌥ or ⌃, so ⌘W and ⌘Q still reach the
    /// menu. Letters go by character, not key code, so they follow the
    /// keyboard layout.
    init?(keyCode: Int, modifiers: NSEvent.ModifierFlags, characters: String?) {
        guard modifiers.isDisjoint(with: [.command, .option, .control]) else { return nil }
        switch keyCode {
        case kVK_UpArrow: self = .move(.up)
        case kVK_DownArrow: self = .move(.down)
        case kVK_LeftArrow: self = .move(.left)
        case kVK_RightArrow: self = .move(.right)
        case kVK_Return, kVK_ANSI_KeypadEnter: self = .open
        case kVK_Tab: self = .switchTab
        case kVK_Delete, kVK_ForwardDelete: self = .clearFilters
        default:
            switch characters {
            case "?", "/": self = .showShortcuts
            case ",": self = .openSettings
            default:
                switch characters?.lowercased() {
                case "k": self = .move(.up)
                case "j": self = .move(.down)
                case "h": self = .move(.left)
                case "l": self = .move(.right)
                case "c": self = .copy
                case "x": self = .hide
                case "u": self = .undoHide
                case "o": self = .nextOwner
                case "t": self = .nextTag
                case "r": self = .refresh
                case "1": self = .showTab(.mine)
                case "2": self = .showTab(.reviews)
                default: return nil
                }
            }
        }
    }

    /// Acts on the selected card, so does nothing until one is picked.
    public var needsCard: Bool {
        switch self {
        case .open, .copy, .hide: true
        default: false
        }
    }
}
