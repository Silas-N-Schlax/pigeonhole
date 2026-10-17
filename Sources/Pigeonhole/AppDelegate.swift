import AppKit
import PigeonholeCore
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    private var state: AppState!
    private var statusItem: NSStatusItem!
    private var board: BoardWindow!
    private var settings: NSWindow?
    /// When the board last hid itself on losing key. A click on the status
    /// item takes key first, so without this the click that should close
    /// the board would hide it and then open it straight back up.
    private var lastHiddenAt = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = Self.buildMainMenu()
        NSApp.applicationIconImage = MarkImage.appIcon()
        state = AppState()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = MarkImage.menuBar(dot: false)
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Pigeonhole"
        }

        board = makeBoardWindow()

        HotKeyCenter.shared.onPress = { [weak self] in self?.toggleBoard() }
        HotKeyCenter.shared.register(state.hotKey)
        state.onHotKeyChange = { HotKeyCenter.shared.register($0) }

        followState()
        state.start()
    }

    // MARK: - Board

    private func makeBoardWindow() -> BoardWindow {
        let root = ThemedRoot {
            BoardView(
                openSettings: { [weak self] in self?.showSettings() },
                close: { [weak self] in self?.hideBoard() }
            )
        }
        .environment(state)
        let window = BoardWindow(
            contentRect: NSRect(origin: .zero, size: AppConfig.Window.boardSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = NSHostingController(rootView: root)
        window.setContentSize(AppConfig.Window.boardSize)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.delegate = self
        return window
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
        } else if Date().timeIntervalSince(lastHiddenAt) > 0.3 {
            toggleBoard()
        }
    }

    private func toggleBoard() {
        if board.isVisible { hideBoard() } else { showBoard() }
    }

    private func showBoard() {
        positionUnderStatusItem()
        state.boardDidOpen()
        NSApp.activate(ignoringOtherApps: true)
        board.makeKeyAndOrderFront(nil)
    }

    private func hideBoard() {
        board.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        guard notification.object as? NSWindow === board, board.isVisible else { return }
        lastHiddenAt = Date()
        hideBoard()
    }

    /// Centred under the status item, kept on the screen whose menu bar
    /// holds it.
    private func positionUnderStatusItem() {
        guard let buttonWindow = statusItem.button?.window,
              let screen = buttonWindow.screen ?? NSScreen.main else {
            board.center()
            return
        }
        let anchor = buttonWindow.frame
        let visible = screen.visibleFrame
        let width = board.frame.width
        let x = min(max(anchor.midX - width / 2, visible.minX + 8), visible.maxX - width - 8)
        board.setFrameTopLeftPoint(NSPoint(x: x, y: anchor.minY - AppConfig.Window.dropBelowMenuBar))
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Refresh", action: #selector(refreshNow), keyEquivalent: "r").target = self
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Pigeonhole",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        // Attach just for this click; left clicks still go to the board.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func refreshNow() {
        Task { await state.refresh() }
    }

    // MARK: - Settings

    @objc private func openSettings() {
        showSettings()
    }

    private func showSettings() {
        if settings == nil {
            let root = ThemedRoot { SettingsView() }.environment(state)
            let window = NSWindow(contentViewController: NSHostingController(rootView: root))
            window.title = "Pigeonhole Settings"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.setContentSize(AppConfig.Window.settingsSize)
            window.center()
            window.setFrameAutosaveName("PigeonholeSettings")
            settings = window
            applyTheme(state.theme)
        }
        hideBoard()
        NSApp.activate(ignoringOtherApps: true)
        settings?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Following state

    /// AppKit pieces SwiftUI can't reach: the window chrome's appearance and
    /// the status item's dot. Re-arms itself after every change it sees.
    private func followState() {
        withObservationTracking {
            applyTheme(state.theme)
            let dot = state.showActionDot && state.needsActionCount > 0
            statusItem.button?.image = MarkImage.menuBar(dot: dot)
        } onChange: { [weak self] in
            Task { @MainActor in self?.followState() }
        }
    }

    private func applyTheme(_ theme: Theme) {
        // Controls SwiftUI draws natively (switches, text fields, menus) take
        // light or dark from the window, not from our colors.
        let appearance = NSAppearance(named: theme.isDark ? .darkAqua : .aqua)
        board?.appearance = appearance
        settings?.appearance = appearance
        settings?.backgroundColor = theme.windowColor
    }

    // MARK: - Main menu

    /// An accessory app still needs a main menu for ⌘C/⌘V in text fields
    /// and ⌘W/⌘Q to work while one of its windows is key.
    private static func buildMainMenu() -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "About Pigeonhole",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit Pigeonhole",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        main.addItem(submenu: appMenu, title: "Pigeonhole")

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(submenu: editMenu, title: "Edit")

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        main.addItem(submenu: windowMenu, title: "Window")

        return main
    }
}

/// Borderless so the board reads as a dropdown rather than a window, but a
/// borderless window refuses key by default, and the board needs key for
/// Escape and for hiding when you click away.
final class BoardWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private extension NSMenu {
    func addItem(submenu: NSMenu, title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        addItem(item)
    }
}
