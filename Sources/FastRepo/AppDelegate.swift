import AppKit
import SwiftUI
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusInfoItem: NSMenuItem!
    private var panel: SearchPanel?
    private let vm = SearchVM()
    private let client = GitHubClient()
    private var hotKey: GlobalHotKey?
    private var refreshTimer: Timer?
    private let tokenPageURL = "https://github.com/settings/tokens/new?scopes=repo,read:org&description=FastRepo"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Use our icon for system UI (alerts etc.); reliable even with LSUIElement.
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: path) {
            NSApp.applicationIconImage = icon
        }
        setupStatusItem()
        setupMainMenu() // gives ⌘X/⌘C/⌘V/⌘A in text fields (no Edit menu otherwise)

        vm.onClose = { [weak self] in self?.hidePanel() }
        vm.hasToken = Keychain.get() != nil
        vm.setItems(Cache.load())
        updateInfo()

        // Global hotkey: Control + Command + G
        hotKey = GlobalHotKey(keyCode: Int(kVK_ANSI_G), modifiers: controlKey | cmdKey) { [weak self] in
            Task { @MainActor in self?.togglePanel() }
        }

        if Keychain.get() == nil {
            promptToken(message: "Paste a GitHub token to begin.")
        } else {
            refresh()
        }

        // Periodic background resync (every 30 min).
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    // MARK: - Status item / menu

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let path = Bundle.main.path(forResource: "MenuIcon", ofType: "png"),
               let img = NSImage(contentsOfFile: path) {
                img.size = NSSize(width: 18, height: 18)
                img.isTemplate = true // monochrome, adapts to light/dark menu bar
                button.image = img
            } else {
                let fallback = NSImage(systemSymbolName: "magnifyingglass.circle", accessibilityDescription: "FastRepo")
                fallback?.isTemplate = true
                button.image = fallback
            }
        }

        let menu = NSMenu()

        statusInfoItem = NSMenuItem(title: "FastRepo", action: nil, keyEquivalent: "")
        menu.addItem(statusInfoItem)
        menu.addItem(.separator())

        let search = NSMenuItem(title: "Search repos & orgs", action: #selector(openPanel), keyEquivalent: "g")
        search.keyEquivalentModifierMask = [.control, .command]
        search.target = self
        menu.addItem(search)

        let refreshItem = NSMenuItem(title: "Refresh now", action: #selector(refreshClicked), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        let tokenItem = NSMenuItem(title: "Set GitHub token…", action: #selector(setTokenClicked), keyEquivalent: "")
        tokenItem.target = self
        menu.addItem(tokenItem)

        let clearItem = NSMenuItem(title: "Clear token", action: #selector(clearTokenClicked), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit FastRepo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit FastRepo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func openPanel() { showPanel() }
    @objc private func refreshClicked() { refresh() }
    @objc private func setTokenClicked() { promptToken(message: "Classic PAT with repo + read:org scopes.") }
    @objc private func clearTokenClicked() {
        Keychain.clear()
        vm.hasToken = false
        vm.setItems([])
        Cache.save([])
        updateInfo()
    }

    @objc private func openTokenPage() {
        if let url = URL(string: tokenPageURL) { NSWorkspace.shared.open(url) }
    }

    // MARK: - Panel

    private func togglePanel() {
        if let panel = panel, panel.isVisible { hidePanel() } else { showPanel() }
    }

    private func showPanel() {
        if panel == nil { buildPanel() }
        guard let panel = panel else { return }

        vm.hasToken = Keychain.get() != nil
        vm.setItems(Cache.load())
        vm.query = ""
        vm.focusTick += 1

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let size = panel.frame.size
            let x = visible.midX - size.width / 2
            let y = visible.midY - size.height / 2 + 120
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func hidePanel() { panel?.orderOut(nil) }

    private func buildPanel() {
        let rect = NSRect(x: 0, y: 0, width: 600, height: 460)
        let p = SearchPanel(contentRect: rect,
                            styleMask: [.titled, .fullSizeContentView],
                            backing: .buffered, defer: false)
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.standardWindowButton(.closeButton)?.isHidden = true
        p.standardWindowButton(.miniaturizeButton)?.isHidden = true
        p.standardWindowButton(.zoomButton)?.isHidden = true
        p.isMovableByWindowBackground = true
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isReleasedWhenClosed = false
        p.hidesOnDeactivate = false

        let hosting = NSHostingView(rootView: SearchView(vm: vm))
        hosting.frame = rect
        p.contentView = hosting

        NotificationCenter.default.addObserver(self, selector: #selector(panelResigned),
                                               name: NSWindow.didResignKeyNotification, object: p)
        panel = p
    }

    @objc private func panelResigned() { hidePanel() }

    // MARK: - Data

    private func refresh() {
        Task {
            do {
                let items = try await client.sync()
                await MainActor.run {
                    self.vm.hasToken = true
                    self.vm.setItems(items)
                    self.updateInfo()
                }
            } catch GHError.unauthorized {
                await MainActor.run { self.promptToken(message: "Token invalid or expired.") }
            } catch GHError.noToken {
                await MainActor.run { self.vm.hasToken = false; self.updateInfo() }
            } catch {
                await MainActor.run { self.updateInfo() } // keep cache on network errors
            }
        }
    }

    private func updateInfo() {
        let repos = vm.all.filter { $0.kind == .repo }.count
        let orgs = vm.all.filter { $0.kind == .org }.count
        statusInfoItem.title = vm.hasToken ? "\(repos) repos · \(orgs) orgs" : "No token set"
    }

    private func promptToken(message: String) {
        let alert = NSAlert()
        alert.messageText = "GitHub Personal Access Token"
        alert.informativeText = message + "\nNeeds a classic token with the repo and read:org scopes."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let width: CGFloat = 360
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 58))

        // Clickable link (opens the pre-filled token page; does not dismiss the dialog).
        let link = NSButton(frame: NSRect(x: 0, y: 32, width: width, height: 20))
        link.isBordered = false
        link.setButtonType(.momentaryChange)
        link.alignment = .left
        link.attributedTitle = NSAttributedString(string: "Create a token on GitHub ↗", attributes: [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: NSFont.systemFont(ofSize: 12),
        ])
        link.target = self
        link.action = #selector(openTokenPage)

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: width, height: 24))
        field.placeholderString = "ghp_… or github_pat_…"

        container.addSubview(link)
        container.addSubview(field)
        alert.accessoryView = container

        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            let token = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty {
                Keychain.set(token)
                vm.hasToken = true
                refresh()
            }
        }
    }
}
