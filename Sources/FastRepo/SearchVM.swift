import AppKit
import SwiftUI

@MainActor
final class SearchVM: ObservableObject {
    @Published var query: String = ""
    @Published var results: [Item] = []
    @Published var selected: Int = 0
    @Published var focusTick: Int = 0   // bump to re-focus the field on show
    @Published var hasToken: Bool = true

    private(set) var all: [Item] = []
    var onClose: @MainActor () -> Void = {}

    func setItems(_ items: [Item]) { all = items; filter() }

    func filter() {
        results = Search.filter(all, query)
        selected = 0
    }

    func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selected = min(max(0, selected + delta), results.count - 1)
    }

    func openSelected() {
        guard results.indices.contains(selected),
              let url = URL(string: results[selected].url) else { return }
        NSWorkspace.shared.open(url)
        onClose()
    }

    func close() { onClose() }
}
