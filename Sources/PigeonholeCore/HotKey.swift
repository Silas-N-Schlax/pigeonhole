import AppKit
import Carbon.HIToolbox

/// A global shortcut, stored as Carbon key code and modifier bits because
/// that's what `RegisterEventHotKey` takes. Carbon hot keys need no
/// Accessibility permission, unlike an event tap.
public struct HotKey: Codable, Equatable {
    public let keyCode: UInt32
    public let modifiers: UInt32
    public let key: String

    public init(keyCode: UInt32, modifiers: UInt32, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    public static let standard = HotKey(
        keyCode: UInt32(kVK_ANSI_P),
        modifiers: UInt32(cmdKey | optionKey),
        key: "P"
    )

    /// In the order macOS menus print them: ⌃⌥⇧⌘.
    public var display: String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        return text + key
    }

    /// Nil unless the press holds ⌘, ⌥ or ⌃. A bare letter as a global
    /// shortcut would swallow that letter in every other app.
    public init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.isDisjoint(with: [.command, .option, .control]) else { return nil }
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        let key = Self.keyNames[Int(event.keyCode)]
            ?? event.charactersIgnoringModifiers?.uppercased() ?? ""
        guard !key.isEmpty else { return nil }
        self.init(keyCode: UInt32(event.keyCode), modifiers: modifiers, key: key)
    }

    static let keyNames: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]
}

@MainActor
public final class HotKeyCenter {
    public static let shared = HotKeyCenter()

    public var onPress: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerInstalled = false

    /// Replaces whatever was registered. False when another app already owns
    /// the combination.
    @discardableResult
    public func register(_ key: HotKey) -> Bool {
        suspend()
        installHandler()
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: 0x5047_484C, id: 1) // "PGHL"
        let status = RegisterEventHotKey(
            key.keyCode, key.modifiers, id, GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr else { return false }
        hotKeyRef = ref
        return true
    }

    /// Lets the settings recorder hear the current shortcut instead of the
    /// board toggling while you're trying to type it.
    public func suspend() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    private func installHandler() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { HotKeyCenter.shared.onPress?() }
            }
            return noErr
        }, 1, &spec, nil, nil)
        handlerInstalled = true
    }
}
