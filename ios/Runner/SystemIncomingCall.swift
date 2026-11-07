import CallKit
import AVFoundation
import Flutter
import WebRTC

/// CallKit presentation, without PushKit registration or background delivery.
final class SystemIncomingCall: NSObject, CXProviderDelegate {
    private let channel: FlutterMethodChannel
    private let provider: CXProvider
    private let controller = CXCallController()
    private var roomID: String?
    private var uuid: UUID?
    private var answered = false
    private var timer: Timer?
    private var muted = false

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "jospar/incoming_call", binaryMessenger: messenger)
        let config = CXProviderConfiguration(localizedName: "Jospar")
        config.supportsVideo = true
        config.maximumCallsPerCallGroup = 1
        config.maximumCallGroups = 1
        config.supportedHandleTypes = [.generic]
        config.includesCallsInRecents = false
        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: .main)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { result(false); return }
            let args = call.arguments as? [String: Any] ?? [:]
            let id = args["id"] as? String ?? ""
            switch call.method {
            case "show": self.show(id: id, name: args["name"] as? String ?? "Jospar", video: args["video"] as? Bool ?? false, result: result)
            case "answer":
                guard id == self.roomID, let uuid = self.uuid else { result(FlutterError(code: "call_gone", message: "Звонок завершён", details: nil)); return }
                if self.answered { result(nil); return }
                self.controller.request(CXTransaction(action: CXAnswerCallAction(call: uuid))) { error in
                    DispatchQueue.main.async { result(error.map { FlutterError(code: "answer_failed", message: $0.localizedDescription, details: nil) }) }
                }
            case "connected": result(nil)
            case "mute":
                guard id == self.roomID, let uuid = self.uuid, self.answered else { result(nil); return }
                let value = args["muted"] as? Bool ?? false
                if self.muted == value { result(nil); return }
                self.controller.request(CXTransaction(action: CXSetMutedCallAction(call: uuid, muted: value))) { error in
                    DispatchQueue.main.async { result(error.map { FlutterError(code: "mute_failed", message: $0.localizedDescription, details: nil) }) }
                }
            case "end":
                if id == self.roomID { self.end(reason: .remoteEnded) }
                result(nil)
            default: result(FlutterMethodNotImplemented)
            }
        }
    }
    private func show(id: String, name: String, video: Bool, result: @escaping FlutterResult) {
        guard !id.isEmpty else { result(false); return }
        if roomID == id { result(true); return }
        if roomID != nil { result(false); return }
        let value = UUID()
        roomID = id; uuid = value; answered = false; muted = false
        // CallKit owns audio activation for this call. Outgoing calls keep the SDK default.
        RTCAudioSession.sharedInstance().useManualAudio = true
        RTCAudioSession.sharedInstance().isAudioEnabled = false
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: name)
        update.localizedCallerName = name
        update.hasVideo = video
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false
        provider.reportNewIncomingCall(with: value, update: update) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { result(false); return }
                if error != nil {
                    if self.uuid == value { self.clear() }
                    result(false)
                    return
                }
                // A remote cancellation may have arrived while CallKit reported the call.
                guard self.uuid == value else {
                    self.provider.reportCall(with: value, endedAt: Date(), reason: .remoteEnded)
                    result(false)
                    return
                }
                self.timer = Timer.scheduledTimer(withTimeInterval: 45, repeats: false) { [weak self] _ in
                    guard let self = self, !self.answered, self.roomID == id else { return }
                    self.send("timeout")
                    self.end(reason: .unanswered)
                }
                result(true)
            }
        }
    }
    private func send(_ action: String, extra: [String: Any] = [:]) {
        guard let id = roomID else { return }
        channel.invokeMethod(action, arguments: extra.merging(["id": id]) { _, new in new })
    }
    private func clear() {
        timer?.invalidate(); timer = nil
        roomID = nil; uuid = nil; answered = false; muted = false
        RTCAudioSession.sharedInstance().useManualAudio = false
    }
    private func end(reason: CXCallEndedReason) {
        if let value = uuid { provider.reportCall(with: value, endedAt: Date(), reason: reason) }
        clear()
    }
    func providerDidReset(_ provider: CXProvider) {
        send("reset")
        clear()
    }
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        guard action.callUUID == uuid else { action.fail(); return }
        answered = true; timer?.invalidate(); timer = nil
        let audio = RTCAudioSession.sharedInstance()
        audio.lockForConfiguration()
        do {
            try audio.setCategory(AVAudioSession.Category.playAndRecord,
                                  with: [.allowBluetooth, .allowBluetoothA2DP])
            try audio.setMode(AVAudioSession.Mode.voiceChat)
        } catch {
            audio.unlockForConfiguration()
            action.fail(); send("end"); end(reason: .failed); return
        }
        audio.unlockForConfiguration()
        action.fulfill()
        send("answer")
    }
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        guard action.callUUID == uuid else { action.fail(); return }
        send(answered ? "end" : "decline")
        clear()
        action.fulfill()
    }
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        guard action.callUUID == uuid else { action.fail(); return }
        muted = action.isMuted
        channel.invokeMethod("mute", arguments: ["id": roomID ?? "", "muted": muted]) { result in
            if result is FlutterError { action.fail() } else { action.fulfill() }
        }
    }
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        let rtc = RTCAudioSession.sharedInstance()
        rtc.audioSessionDidActivate(audioSession)
        rtc.isAudioEnabled = true
    }
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        let rtc = RTCAudioSession.sharedInstance()
        rtc.isAudioEnabled = false
        rtc.audioSessionDidDeactivate(audioSession)
        if roomID == nil { rtc.useManualAudio = false }
    }
}
