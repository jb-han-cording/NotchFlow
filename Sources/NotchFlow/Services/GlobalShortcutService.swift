import Carbon
import Foundation
@MainActor final class GlobalShortcutService {
    var onPressed: (() -> Void)?
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let signature: OSType = 0x4E464C57
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr, identifier.signature == 0x4E464C57 else { return OSStatus(eventNotHandledErr) }
            let service = Unmanaged<GlobalShortcutService>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in service.onPressed?() }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func register(_ choice: String) -> String? {
        if let reference { UnregisterEventHotKey(reference) }; reference = nil
        guard choice != "Disabled" else { return nil }
        let modifiers: UInt32
        switch choice {
        case "Control + Option + Space": modifiers = UInt32(controlKey | optionKey)
        case "Command + Shift + Space": modifiers = UInt32(cmdKey | shiftKey)
        default: modifiers = UInt32(optionKey)
        }
        let result = RegisterEventHotKey(UInt32(kVK_Space), modifiers, EventHotKeyID(signature: signature, id: 1), GetApplicationEventTarget(), 0, &reference)
        return result == noErr ? nil : "단축키를 등록하지 못했습니다. 다른 조합을 선택하세요. (\(result))"
    }
    func stop() { if let reference { UnregisterEventHotKey(reference) }; if let handler { RemoveEventHandler(handler) }; reference = nil; handler = nil }
}
