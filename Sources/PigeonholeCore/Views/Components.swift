import SwiftUI

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.mailroom
}

private struct TypographyKey: EnvironmentKey {
    static let defaultValue = Typography(preset: .standard, size: .regular)
}

public extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }

    var typography: Typography {
        get { self[TypographyKey.self] }
        set { self[TypographyKey.self] = newValue }
    }
}

/// Hands the current theme and fonts to everything below it. Each window's
/// root view sits inside one.
public struct ThemedRoot<Content: View>: View {
    @Environment(AppState.self) private var state
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .environment(\.theme, state.theme)
            .environment(\.typography, state.typography)
            .tint(state.theme.accent)
    }
}

struct SegmentItem<ID: Hashable> {
    let id: ID
    let label: String
    var badge: Int?
}

struct SegmentedControl<ID: Hashable>: View {
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    let items: [SegmentItem<ID>]
    @Binding var selection: ID

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.id) { item in
                let on = item.id == selection
                Button {
                    selection = item.id
                } label: {
                    HStack(spacing: 6) {
                        Text(item.label)
                            .font(type.ui(12.5, on ? .semibold : .medium))
                        if let badge = item.badge {
                            Text("\(badge)")
                                .font(type.ui(10.5, .bold))
                                .monospacedDigit()
                                .foregroundStyle(theme.accentText)
                                .padding(.horizontal, 4)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Capsule().fill(theme.accent))
                        }
                    }
                    .foregroundStyle(on ? theme.text : theme.dim)
                    .padding(.horizontal, 11)
                    .frame(height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(on ? theme.segOn : .clear)
                            .shadow(color: on ? theme.shadow : .clear, radius: 1, y: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 7).fill(theme.seg))
    }
}

struct TagChip: View {
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    let name: String
    let slot: Int

    var body: some View {
        let color = theme.tag(slot)
        Text(name.isEmpty ? "Untitled" : name)
            .font(type.ui(10.5, .semibold))
            .lineLimit(1)
            .foregroundStyle(color.text)
            .padding(.horizontal, 6)
            .frame(height: 17)
            .background(Capsule().fill(color.fill))
    }
}

struct StatusChip: View {
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    let status: Status

    var body: some View {
        let colors = theme.chip(status.tone)
        Text(status.label)
            .font(type.ui(11, .medium))
            .lineLimit(1)
            .foregroundStyle(colors.text)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(RoundedRectangle(cornerRadius: 5).fill(colors.fill))
    }
}

struct Dot: View {
    let color: Color
    var size: CGFloat = 7

    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
    }
}

struct SectionLabel: View {
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(type.ui(11, .semibold))
            .tracking(0.6)
            .foregroundStyle(theme.dim)
    }
}

struct CardBackground: ViewModifier {
    @Environment(\.theme) private var theme
    var radius: CGFloat = 9
    var highlighted = false

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius).fill(theme.card))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(highlighted ? theme.accent : theme.cardLine, lineWidth: highlighted ? 1.5 : 1)
            )
    }
}

extension View {
    func card(radius: CGFloat = 9, highlighted: Bool = false) -> some View {
        modifier(CardBackground(radius: radius, highlighted: highlighted))
    }
}

/// Lays children out in rows, wrapping when a row runs out of width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
