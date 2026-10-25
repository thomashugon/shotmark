import Carbon.HIToolbox
import Foundation

/// Global keyboard shortcuts, via the Carbon hot key API (no Accessibility permission needed).
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var handlers: [UInt32: @MainActor () -> Void] = [:]
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    private let signature = OSType(0x53_4D_52_4B) // "SMRK"

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping @MainActor () -> Void) {
        installEventHandlerIfNeeded()
        let id = UInt32(handlers.count + 1)
        handlers[id] = handler

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            hotKeyRefs.append(ref)
        } else {
            NSLog("ShotMark: impossible d'enregistrer le raccourci \(keyCode) (\(status))")
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil,
                              &hotKeyID)
            let id = hotKeyID.id
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    HotKeyManager.shared.handlers[id]?()
                }
            }
            return noErr
        }, 1, &spec, nil, &eventHandler)
    }
}
