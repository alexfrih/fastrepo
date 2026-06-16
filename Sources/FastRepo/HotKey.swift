import AppKit
import Carbon.HIToolbox

// Minimal global hotkey via Carbon RegisterEventHotKey.
// Carbon hotkeys work without Accessibility/Input-Monitoring permission,
// unlike NSEvent global monitors.
final class GlobalHotKey {
    private var ref: EventHotKeyRef?
    private let myID: UInt32

    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false
    private static let signature: OSType = "RPJP".utf8.reduce(UInt32(0)) { ($0 << 8) + UInt32($1) }

    init?(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        self.myID = GlobalHotKey.nextID
        GlobalHotKey.nextID += 1
        GlobalHotKey.installHandlerIfNeeded()
        GlobalHotKey.actions[myID] = action

        let hkID = EventHotKeyID(signature: GlobalHotKey.signature, id: myID)
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hkID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status != noErr {
            NSLog("FastRepo: hotkey registration FAILED (status=%d) — combo likely taken by another app", status)
            GlobalHotKey.actions[myID] = nil
            return nil
        }
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        GlobalHotKey.actions[myID] = nil
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, _) -> OSStatus in
            guard let event = event else { return OSStatus(eventNotHandledErr) }
            var hkID = EventHotKeyID()
            let err = GetEventParameter(event,
                                        EventParamName(kEventParamDirectObject),
                                        EventParamType(typeEventHotKeyID),
                                        nil,
                                        MemoryLayout<EventHotKeyID>.size,
                                        nil,
                                        &hkID)
            if err == noErr, let action = GlobalHotKey.actions[hkID.id] {
                DispatchQueue.main.async { action() }
            }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
