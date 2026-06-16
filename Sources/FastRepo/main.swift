import AppKit

// Program entry runs on the main thread; enter the main actor explicitly so we
// can construct the @MainActor AppDelegate. app.run() blocks here for the app's
// lifetime, which also keeps `delegate` alive (NSApplication.delegate is weak).
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory) // menu-bar app: no dock icon
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
