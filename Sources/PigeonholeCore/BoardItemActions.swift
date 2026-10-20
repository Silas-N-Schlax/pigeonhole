import AppKit

extension BoardItem {
    /// The branch goes on the clipboard for pasting into time tracking. A
    /// branch that was never pushed has no page yet, so its clone opens.
    func openCopyingBranch() {
        copyBranch()
        switch self {
        case .pullRequest(let pr): NSWorkspace.shared.open(pr.url)
        case .branch(let branch): NSWorkspace.shared.open(branch.url ?? branch.directory)
        }
    }

    func copyBranch() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(branchName, forType: .string)
    }
}
