import AppKit
import Carbon.HIToolbox

// MARK: - Global Hot Key
/// A system-wide shortcut that works while WhispNotes is in the background (for example during a call).
/// Uses Carbon's RegisterEventHotKey, which needs no Accessibility permission.
final class GlobalHotKey {
    static let shared = GlobalHotKey()

    /// ⌃⌥⌘R. Rarely bound by other apps, and R for record.
    static let displayString = "⌃⌥⌘R"

    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    var isRegistered: Bool { hotKeyRef != nil }

    func register() {
        guard hotKeyRef == nil else { return }
        installHandlerIfNeeded()
        let id = EventHotKeyID(signature: OSType(0x574E_5243), id: 1) // "WNRC"
        let modifiers = UInt32(controlKey | optionKey | cmdKey)
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_R), modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            hotKeyRef = nil
            WhispLogger.log("Global shortcut \(Self.displayString) could not be registered (status \(status)); another app may own it.", category: "HotKey")
        }
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { GlobalHotKey.shared.onPress?() }
            return noErr
        }, 1, &eventType, nil, &handlerRef)
    }
}
