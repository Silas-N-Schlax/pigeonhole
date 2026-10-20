import Foundation

/// A card you've hidden from the board. Keeps a label so Settings can name
/// it after the card itself has gone from view.
public struct HiddenItem: Identifiable, Codable, Equatable {
    public let id: String
    public let label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}
