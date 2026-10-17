import AppKit
import Carbon.HIToolbox
import SwiftUI

enum SettingsTab: Hashable {
    case general, appearance, tags
}

public struct SettingsView: View {
    @Environment(\.theme) private var theme
    @State private var tab: SettingsTab

    public init() {
        _tab = State(initialValue: .general)
    }

    init(tab: SettingsTab) {
        _tab = State(initialValue: tab)
    }

    public var body: some View {
        VStack(spacing: 0) {
            SegmentedControl(
                items: [
                    SegmentItem(id: SettingsTab.general, label: "General"),
                    SegmentItem(id: SettingsTab.appearance, label: "Appearance"),
                    SegmentItem(id: SettingsTab.tags, label: "Tags"),
                ],
                selection: $tab
            )
            .padding(.top, 34)
            .padding(.bottom, 6)
            ScrollView {
                Group {
                    switch tab {
                    case .general: GeneralPane()
                    case .appearance: AppearancePane()
                    case .tags: TagsPane()
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
        }
        .frame(width: AppConfig.Window.settingsSize.width, height: AppConfig.Window.settingsSize.height)
        .background(theme.window)
        .foregroundStyle(theme.text)
    }
}

// MARK: - General

private struct GeneralPane: View {
    @Environment(AppState.self) private var state
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    @State private var opensAtLogin = false
    @State private var loginError: String?

    var body: some View {
        @Bindable var state = state
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("GitHub")
                HStack(spacing: 10) {
                    Dot(color: state.board == nil ? theme.danger : theme.good, size: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.board == nil ? "Not connected yet" : "Signed in through GitHub CLI as \(state.viewer)")
                            .font(type.ui(13, .semibold))
                        Text(state.errorMessage ?? "Read-only. Pigeonhole only runs searches.")
                            .font(type.ui(11.5))
                            .foregroundStyle(theme.faint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .card()
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Shortcut")
                HStack {
                    Text("Open Pigeonhole").font(type.ui(13))
                    Spacer()
                    HotKeyRecorder()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .card()
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Refresh every")
                SegmentedControl(
                    items: AppConfig.Refresh.minuteOptions.map { SegmentItem(id: $0, label: "\($0) min") },
                    selection: $state.refreshMinutes
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Show PRs active in the last")
                SegmentedControl(
                    items: ActivityWindow.allCases.map { SegmentItem(id: $0, label: $0.label) },
                    selection: $state.activityWindow
                )
                Text("Older PRs stay hidden until someone pushes, comments or reviews.")
                    .font(type.ui(11.5))
                    .foregroundStyle(theme.faint)
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Behavior")
                VStack(spacing: 0) {
                    Toggle(isOn: $opensAtLogin) {
                        Text("Open at login").font(type.ui(13))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    theme.cardLine.frame(height: 1)
                    Toggle(isOn: $state.showActionDot) {
                        Text("Dot on the menu bar icon when something needs action")
                            .font(type.ui(13))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .card()
                if let loginError {
                    Text(loginError)
                        .font(type.ui(11.5))
                        .foregroundStyle(theme.danger)
                }
            }
        }
        .onAppear { opensAtLogin = state.opensAtLogin }
        .onChange(of: opensAtLogin) { _, on in
            guard on != state.opensAtLogin else { return }
            do {
                try state.setOpensAtLogin(on)
                loginError = nil
            } catch {
                loginError = "macOS said no: \(error.localizedDescription)"
                opensAtLogin = state.opensAtLogin
            }
        }
    }
}

private struct HotKeyRecorder: View {
    @Environment(AppState.self) private var state
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            Text(recording ? "Type a shortcut…" : state.hotKey.display)
                .font(type.ui(12.5, .semibold))
                .foregroundStyle(recording ? theme.accentSoftText : theme.text)
                .padding(.horizontal, 12)
                .frame(minWidth: 70, minHeight: 26)
                .background(RoundedRectangle(cornerRadius: 6).fill(recording ? theme.accentSoft : theme.control))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(recording ? theme.accent : theme.controlLine))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Click, then press the keys. Escape cancels.")
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        HotKeyCenter.shared.suspend()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stop()
            } else if let key = HotKey(event: event) {
                state.hotKey = key
                stop()
            }
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard recording else { return }
        recording = false
        HotKeyCenter.shared.register(state.hotKey)
    }
}

// MARK: - Appearance

private struct AppearancePane: View {
    @Environment(AppState.self) private var state
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type

    var body: some View {
        @Bindable var state = state
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Theme")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(Theme.all) { option in
                        ThemeCard(option: option, selected: option.id == state.themeID) {
                            state.themeID = option.id
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Font")
                VStack(spacing: 4) {
                    ForEach(FontPreset.all) { preset in
                        FontRow(preset: preset, selected: preset.id == state.fontPresetID) {
                            state.fontPresetID = preset.id
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Text size")
                SegmentedControl(
                    items: TextSize.allCases.map { SegmentItem(id: $0, label: $0.label) },
                    selection: $state.textSize
                )
            }
        }
    }
}

private struct ThemeCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    let option: Theme
    let selected: Bool
    let pick: () -> Void

    var body: some View {
        Button(action: pick) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        VStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(index == 2 ? option.accent : option.card)
                                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(index == 2 ? .clear : option.cardLine))
                                .frame(height: 12)
                            Spacer(minLength: 0)
                        }
                        .padding(3)
                        .background(RoundedRectangle(cornerRadius: 3).fill(option.slot))
                    }
                }
                .padding(5)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 6).fill(option.window))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(option.line))
                HStack(alignment: .firstTextBaseline) {
                    Text(option.name).font(type.ui(12.5, .semibold))
                    Spacer()
                    Text(option.isDark ? "Dark" : "Light")
                        .font(type.ui(10.5))
                        .foregroundStyle(theme.faint)
                }
                Text(option.blurb)
                    .font(type.ui(11))
                    .foregroundStyle(theme.dim)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .card(highlighted: selected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct FontRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    let preset: FontPreset
    let selected: Bool
    let pick: () -> Void

    var body: some View {
        Button(action: pick) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(Typography.font(preset.ui, 13.5, .semibold, fallback: .default))
                        .foregroundStyle(selected ? theme.accentSoftText : theme.text)
                    Text(preset.blurb)
                        .font(type.ui(11))
                        .foregroundStyle(theme.faint)
                }
                Spacer()
                Text("#142 reports-export")
                    .font(Typography.font(preset.mono, 11.5, .regular, fallback: .monospaced))
                    .foregroundStyle(theme.dim)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? theme.accentSoft : theme.card))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selected ? theme.accent : theme.cardLine))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Tags

private struct TagsPane: View {
    @Environment(AppState.self) private var state
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    @State private var editingID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text("Tags show on every card from their repos. Each theme has its own tag colors, so they stay readable in all of them.")
                    .font(type.ui(12))
                    .foregroundStyle(theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    editingID = state.addTag()
                } label: {
                    Text("New tag")
                        .font(type.ui(12.5, .semibold))
                        .foregroundStyle(theme.accentText)
                        .padding(.horizontal, 11)
                        .frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: 7).fill(theme.accent))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if state.tags.isEmpty {
                Text("No tags yet. Make one, then pick the repos it covers.")
                    .font(type.ui(12.5))
                    .foregroundStyle(theme.faint)
                    .padding(.vertical, 8)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(state.tags) { tag in
                        TagPill(tag: tag, selected: tag.id == editing?.id) {
                            editingID = tag.id
                        }
                    }
                }
            }

            if let editing {
                TagEditor(tag: editing) {
                    state.deleteTag(editing.id)
                    editingID = state.tags.first?.id
                }
                .id(editing.id)
            }
        }
        .onAppear { if editingID == nil { editingID = state.tags.first?.id } }
        .task { await state.loadReposIfNeeded() }
    }

    private var editing: Tag? {
        state.tags.first { $0.id == editingID }
    }
}

private struct TagPill: View {
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    let tag: Tag
    let selected: Bool
    let pick: () -> Void
    // Circular corners spelled out: Capsule drew these with flat ends.
    private let pill = RoundedRectangle(cornerRadius: 15, style: .circular)

    var body: some View {
        Button(action: pick) {
            HStack(spacing: 7) {
                Dot(color: theme.tag(tag.colorSlot).dot, size: 8)
                Text(tag.name.isEmpty ? "Untitled" : tag.name).font(type.ui(12.5, .medium))
                Text("\(tag.repos.count)")
                    .font(type.ui(11))
                    .foregroundStyle(theme.faint)
            }
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(pill.fill(selected ? theme.accentSoft : theme.card))
            .overlay(pill.strokeBorder(selected ? theme.accent : theme.cardLine))
            .contentShape(pill)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct TagEditor: View {
    @Environment(AppState.self) private var state
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    @State private var query = ""
    let tag: Tag
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Name")
                TextField("Tag name", text: Binding(
                    get: { tag.name },
                    set: { state.renameTag(tag.id, to: $0) }
                ))
                .textFieldStyle(.plain)
                .font(type.ui(13))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 7).fill(theme.window))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(theme.controlLine))
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Color")
                HStack(spacing: 7) {
                    ForEach(Theme.slotNames.indices, id: \.self) { slot in
                        Button {
                            state.setColor(tag.id, slot: slot)
                        } label: {
                            Circle()
                                .fill(theme.tag(slot).dot)
                                .frame(width: 18, height: 18)
                                .padding(2)
                                .overlay(Circle().strokeBorder(tag.colorSlot == slot ? theme.text : .clear, lineWidth: 2))
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help(Theme.slotNames[slot])
                        .accessibilityLabel(Theme.slotNames[slot])
                    }
                    Spacer()
                    TagChip(name: tag.name, slot: tag.colorSlot)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Repos")
                TextField("Search your repos and ones you contribute to", text: $query)
                    .textFieldStyle(.plain)
                    .font(type.ui(12.5))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: 7).fill(theme.window))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(theme.controlLine))
                if state.isLoadingRepos {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.mini)
                        Text("Loading your repos…").font(type.ui(12)).foregroundStyle(theme.faint)
                    }
                    .padding(.vertical, 6)
                }
                repoGroup("Picked", tag.repos.filter(matches))
                repoGroup("Your repos", state.catalog.own.filter { !tag.holds($0) && matches($0) })
                repoGroup("Repos you contribute to", state.catalog.contributed.filter { !tag.holds($0) && matches($0) })
            }

            Button("Delete tag", role: .destructive, action: delete)
                .buttonStyle(.plain)
                .font(type.ui(12))
                .foregroundStyle(theme.danger)
        }
        .padding(14)
        .card(radius: 10)
    }

    private func matches(_ repo: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || repo.localizedCaseInsensitiveContains(trimmed)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(type.ui(11.5, .semibold))
            .foregroundStyle(theme.dim)
    }

    @ViewBuilder
    private func repoGroup(_ title: String, _ repos: [String]) -> some View {
        if !repos.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(type.ui(10.5, .semibold))
                    .tracking(0.5)
                    .foregroundStyle(theme.faint)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                ForEach(repos, id: \.self) { repo in
                    RepoRow(repo: repo, tag: tag)
                }
            }
        }
    }
}

private struct RepoRow: View {
    @Environment(AppState.self) private var state
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    let repo: String
    let tag: Tag

    var body: some View {
        let on = tag.holds(repo)
        let parts = repo.split(separator: "/", maxSplits: 1).map(String.init)
        let others = state.tags.filter { $0.id != tag.id && $0.holds(repo) }.map(\.name)
        Button {
            state.toggleRepo(repo, in: tag.id)
        } label: {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(on ? theme.accent : theme.window)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(on ? .clear : theme.controlLine, lineWidth: 1.5))
                    .overlay {
                        if on {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(theme.accentText)
                        }
                    }
                    .frame(width: 15, height: 15)
                (Text("\(parts.first ?? "")/").foregroundColor(theme.faint)
                    + Text(parts.last ?? "").foregroundColor(theme.text))
                    .font(type.mono(12))
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(others.joined(separator: ", "))
                    .font(type.ui(10.5))
                    .foregroundStyle(theme.faint)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
