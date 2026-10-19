import AppKit

extension PullRequest {
    /// The branch goes on the clipboard for pasting into time tracking.
    func openCopyingBranch() {
        copyBranch()
        NSWorkspace.shared.open(url)
    }

    func copyBranch() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(branch, forType: .string)
    }
}
