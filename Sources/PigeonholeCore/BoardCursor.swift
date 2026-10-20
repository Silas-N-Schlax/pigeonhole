public enum CursorMove {
    case up, down, left, right
}

/// The keyboard selection. Remembers where its card sat as well as which
/// card, so when a refresh or a filter takes the card away the cursor lands
/// on its nearest neighbour instead of vanishing.
public struct BoardCursor: Equatable {
    public let id: String
    let column: Int
    let row: Int

    init(id: String, column: Int, row: Int) {
        self.id = id
        self.column = column
        self.row = row
    }

    private init<Item: Identifiable>(_ columns: [[Item]], column: Int, row: Int) where Item.ID == String {
        self.init(id: columns[column][row].id, column: column, row: row)
    }

    public static func first<Item: Identifiable>(in columns: [[Item]]) -> BoardCursor? where Item.ID == String {
        guard let column = columns.firstIndex(where: { !$0.isEmpty }) else { return nil }
        return BoardCursor(columns, column: column, row: 0)
    }

    public static func on<Item: Identifiable>(_ id: String, in columns: [[Item]]) -> BoardCursor? where Item.ID == String {
        for (column, items) in columns.enumerated() {
            if let row = items.firstIndex(where: { $0.id == id }) {
                return BoardCursor(id: id, column: column, row: row)
            }
        }
        return nil
    }

    /// Nil only when every column is empty.
    public func resolved<Item: Identifiable>(in columns: [[Item]]) -> BoardCursor? where Item.ID == String {
        if let found = Self.on(id, in: columns) { return found }
        let filled = columns.indices.filter { !columns[$0].isEmpty }
        guard let nearest = filled.min(by: { abs($0 - column) < abs($1 - column) }) else { return nil }
        return BoardCursor(columns, column: nearest, row: min(row, columns[nearest].count - 1))
    }

    /// Expects a cursor already resolved against `columns`. Stops at the
    /// edges rather than wrapping, and skips empty columns sideways.
    public func moved<Item: Identifiable>(_ move: CursorMove, in columns: [[Item]]) -> BoardCursor where Item.ID == String {
        switch move {
        case .up:
            return row > 0 ? BoardCursor(columns, column: column, row: row - 1) : self
        case .down:
            return row < columns[column].count - 1 ? BoardCursor(columns, column: column, row: row + 1) : self
        case .left:
            return sideways(to: stride(from: column - 1, through: 0, by: -1), in: columns)
        case .right:
            return sideways(to: stride(from: column + 1, to: columns.count, by: 1), in: columns)
        }
    }

    private func sideways<Item: Identifiable>(
        to candidates: some Sequence<Int>, in columns: [[Item]]
    ) -> BoardCursor where Item.ID == String {
        guard let next = candidates.first(where: { !columns[$0].isEmpty }) else { return self }
        return BoardCursor(columns, column: next, row: min(row, columns[next].count - 1))
    }
}
