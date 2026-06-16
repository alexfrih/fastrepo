import SwiftUI

struct SearchView: View {
    @ObservedObject var vm: SearchVM
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Jump to a repo or org…", text: $vm.query)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .focused($focused)
                .onSubmit { vm.openSelected() }

            Divider()

            if vm.results.isEmpty {
                emptyState
            } else {
                resultsList
            }

            footer
        }
        .frame(width: 600)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .onKeyPress(.downArrow) { vm.move(1); return .handled }
        .onKeyPress(.upArrow) { vm.move(-1); return .handled }
        .onKeyPress(.escape) { vm.close(); return .handled }
        .onChange(of: vm.query) { _, _ in vm.filter() }
        .onAppear { focused = true }
        .onChange(of: vm.focusTick) { _, _ in focused = true }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.results.indices, id: \.self) { idx in
                        RowView(item: vm.results[idx], selected: idx == vm.selected)
                            .id(idx)
                            .contentShape(Rectangle())
                            .onTapGesture { vm.selected = idx; vm.openSelected() }
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(height: 360)
            .onChange(of: vm.selected) { _, n in
                proxy.scrollTo(n, anchor: .center)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text(vm.hasToken ? "No matches" : "No GitHub token yet")
                .foregroundStyle(.secondary)
            if !vm.hasToken {
                Text("Menu-bar icon → Set GitHub token…")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack {
            Text("\(vm.results.count) results")
            Spacer()
            Text("↑↓ move · return open · esc close")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(Divider(), alignment: .top)
    }
}

private struct RowView: View {
    let item: Item
    let selected: Bool

    private var timeText: String { RelTime.short(item.pushedAt) }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: item.kind == .org ? "building.2" : "folder")
                .frame(width: 18)
                .foregroundStyle(selected ? Color.white : .secondary)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(item.title).fontWeight(.semibold)
                    if item.isPrivate {
                        Image(systemName: "lock.fill").font(.system(size: 9))
                    }
                    if item.kind == .org {
                        Text("ORG")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(selected ? Color.white.opacity(0.85) : .secondary)
            }

            Spacer()

            if !timeText.isEmpty {
                Text(timeText)
                    .font(.caption)
                    .foregroundStyle(selected ? Color.white.opacity(0.85) : .secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Color.accentColor : Color.clear)
        .foregroundStyle(selected ? Color.white : Color.primary)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .padding(.horizontal, 6)
    }
}
