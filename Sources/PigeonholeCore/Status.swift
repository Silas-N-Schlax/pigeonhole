import Foundation

public enum Slot: Int, CaseIterable, Identifiable {
    case inProgress, inReview, needsAction

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .inProgress: "In progress"
        case .inReview: "In review"
        case .needsAction: "Needs action"
        }
    }
}

/// Which chip colors a status wears. Maps onto tag palette slots in the
/// theme, so status chips stay readable in every theme for free.
public enum StatusTone: Equatable {
    case draft, review, comments, approved, failing
}

/// Where a PR goes on the board and what its chip says. Checked in order,
/// most urgent first: whatever you'd have to do next is what the chip names.
public struct Status: Equatable {
    public let slot: Slot
    public let label: String
    public let tone: StatusTone

    public init(_ pr: PullRequest) {
        let approved = pr.reviewDecision == .approved
            || (pr.reviewDecision == nil && pr.approvals > 0)

        if pr.isDraft {
            self.init(.inProgress, "Draft", .draft)
        } else if pr.reviewDecision == .changesRequested {
            self.init(.needsAction, "Changes requested", .comments)
        } else if pr.checks == .failing {
            self.init(.needsAction, "CI failing", .failing)
        } else if pr.unresolvedThreads > 0 {
            let comments = plural(pr.unresolvedThreads, "unresolved comment")
            self.init(.needsAction, approved ? "Approved · \(comments)" : comments, .comments)
        } else if approved && pr.checks == .running {
            // Nothing to do until the checks land, so it waits in review.
            self.init(.inReview, "Approved · CI running", .approved)
        } else if approved {
            self.init(.needsAction, "Approved · ready to merge", .approved)
        } else if pr.approvals > 0 {
            self.init(.inReview, "\(pr.approvals) approved", .review)
        } else if pr.pendingReviewers > 0 {
            self.init(.inReview, "Waiting on \(plural(pr.pendingReviewers, "reviewer"))", .review)
        } else {
            self.init(.inReview, "Waiting for review", .review)
        }
    }

    init(_ slot: Slot, _ label: String, _ tone: StatusTone) {
        self.slot = slot
        self.label = label
        self.tone = tone
    }
}

/// How far back a PR's last activity can be and still show. A PR nobody has
/// touched in months is usually abandoned, not waiting on you.
public enum ActivityWindow: String, CaseIterable, Identifiable {
    case all, days14, days30, days60, days90, year

    public static let standard = ActivityWindow.days30

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .all: "All"
        case .days14: "14 days"
        case .days30: "30 days"
        case .days60: "60 days"
        case .days90: "90 days"
        case .year: "1 year"
        }
    }

    var days: Int? {
        switch self {
        case .all: nil
        case .days14: 14
        case .days30: 30
        case .days60: 60
        case .days90: 90
        case .year: 365
        }
    }

    public func includes(_ pr: PullRequest, now: Date) -> Bool {
        guard let days else { return true }
        return now.timeIntervalSince(pr.updatedAt) <= TimeInterval(days) * 86_400
    }
}

public enum Age {
    /// "now", "12m", "3h", "2d", "3w", "4mo", "1y", for a card's corner.
    public static func short(from date: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        let day = 86_400
        switch seconds {
        case ..<60: return "now"
        case ..<3_600: return "\(seconds / 60)m"
        case ..<day: return "\(seconds / 3_600)h"
        case ..<(day * 7): return "\(seconds / day)d"
        case ..<(day * 30): return "\(seconds / (day * 7))w"
        case ..<(day * 365): return "\(seconds / (day * 30))mo"
        default: return "\(seconds / (day * 365))y"
        }
    }
}
