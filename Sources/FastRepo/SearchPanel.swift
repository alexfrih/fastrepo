import AppKit

// Borderless-feeling floating panel that can take keyboard focus
// (NSPanel won't become key by default when the titlebar is hidden).
final class SearchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
