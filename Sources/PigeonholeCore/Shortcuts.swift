import AppKit
import Carbon.HIToolbox

public enum ShortcutGroup: String, CaseIterable {
    case card = "Selected card"
    case board = "Board"
    case app = "Pigeonhole"
}

/// One row of the shortcut palette. Each row runs the same command its key
/// does, so the palette can't drift from what the keys really do.
public struct Shortcut: Identifiable, Equatable {
    public let command: BoardCommand
    public let title: String
    public let keys: [String]
    public let group: ShortcutGroup

    public var id: String { title }

    public static let all: [Shortcut] = [
        Shortcut(command: .open, title: "Open in browser", keys: ["↩"], group: .card),
        Shortcut(command: .copyBranch, title: "Copy branch name", keys: ["C"], group: .card),
        Shortcut(command: .hide, title: "Hide from board", keys: ["X"], group: .card),
        Shortcut(command: .undoHide, title: "Bring back last hidden", keys: ["U"], group: .card),
        Shortcut(command: .showTab(.mine), title: "Show My PRs", keys: ["1"], group: .board),
        Shortcut(command: .showTab(.reviews), title: "Show Reviews", keys: ["2"], group: .board),
        Shortcut(command: .nextOwner, title: "Next owner filter", keys: ["O"], group: .board),
        Shortcut(command: .nextTag, title: "Next tag filter", keys: ["T"], group: .board),
        Shortcut(command: .clearFilters, title: "Clear filters", keys: ["⌫"], group: .board),
        Shortcut(command: .refresh, title: "Refresh now", keys: ["R"], group: .board),
        Shortcut(command: .openSettings, title: "Open Settings", keys: [","], group: .app),
    ]

    /// Every word has to appear somewhere in the title, in any order.
    public static func matching(_ query: String) -> [Shortcut] {
        let words = query.lowercased().split(separator: " ")
        return all.filter { shortcut in
            let title = shortcut.title.lowercased()
            return words.allSatisfy { title.contains($0) }
        }
    }
}

/// The open palette: what's been typed and which row is lit.
public struct ShortcutPalette: Equatable {
    public var query = ""
    public private(set) var index = 0

    public init() {}

    public var matches: [Shortcut] { Shortcut.matching(query) }

    public var highlighted: Shortcut? {
        let matches = matches
        return matches.indices.contains(index) ? matches[index] : nil
    }

    /// Wraps, since the list is short enough that wrapping never loses you.
    mutating func move(by step: Int) {
        let count = matches.count
        guard count > 0 else { return }
        index = ((index + step) % count + count) % count
    }

    mutating func highlight(_ shortcut: Shortcut) {
        if let found = matches.firstIndex(of: shortcut) { index = found }
    }

    mutating func type(_ text: String) {
        query += text
        index = 0
    }

    mutating func erase() {
        guard !query.isEmpty else { return }
        query.removeLast()
        index = 0
    }
}

/// What a key press means while the palette is open. Everything typed goes
/// to its filter, so the board's letter keys rest until it closes.
public enum PaletteKey: Equatable {
    case close, up, down, run, erase
    case type(String)

    public init?(event: NSEvent) {
        self.init(keyCode: Int(event.keyCode), modifiers: event.modifierFlags, characters: event.characters)
    }

    init?(keyCode: Int, modifiers: NSEvent.ModifierFlags, characters: String?) {
        guard modifiers.isDisjoint(with: [.command, .option]) else { return nil }
        let control = modifiers.contains(.control)
        switch keyCode {
        case kVK_Escape: self = .close
        case kVK_UpArrow: self = .up
        case kVK_DownArrow: self = .down
        case kVK_Return, kVK_ANSI_KeypadEnter: self = .run
        case kVK_Delete: self = .erase
        case kVK_ANSI_P where control: self = .up
        case kVK_ANSI_N where control: self = .down
        default:
            // AppKit hands arrow and function keys over as private-use
            // characters, which would otherwise land in the filter.
            guard !control, let characters, let scalar = characters.unicodeScalars.first,
                  !CharacterSet.controlCharacters.contains(scalar),
                  !(0xF700...0xF8FF).contains(scalar.value) else { return nil }
            self = .type(characters)
        }
    }
}
