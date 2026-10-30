import AppKit

extension BoardItem {
    /// The copy goes on the clipboard for pasting into time tracking. A
    /// branch that was never pushed has no page yet, so its clone opens.
    func open(copying text: String) {
        copy(text)
        switch self {
        case .pullRequest(let pr): NSWorkspace.shared.open(pr.url)
        case .branch(let branch): NSWorkspace.shared.open(branch.url ?? branch.directory)
        }
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
