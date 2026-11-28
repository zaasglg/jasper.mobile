//
//  SampleHandler.swift
//  Broadcast Extension
//
//  Created by Alex-Dan Bumbu on 04.06.2021.
//

import ReplayKit
import OSLog

let broadcastLogger = OSLog(subsystem: "com.josparbee.app.CallBroadcast", category: "Broadcast")
private enum Constants {
    // the App Group ID value that the app and the broadcast extension targets are setup with. It differs for each app.
    static let appGroupIdentifier = "group.com.josparbee.app"
}

class SampleHandler: RPBroadcastSampleHandler {

    private var clientConnection: SocketConnection?
    private var uploader: SampleUploader?

    private var frameCount: Int = 0
    private var connectionTimer: DispatchSourceTimer?
    private var finishing = false

    var socketFilePath: String {
      let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier)
        return sharedContainer?.appendingPathComponent("rtc_SSFD").path ?? ""
    }

    override init() {
      super.init()
        if let connection = SocketConnection(filePath: socketFilePath) {
          clientConnection = connection
          setupConnection()

          uploader = SampleUploader(connection: connection)
        }
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(), { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let handler = Unmanaged<SampleHandler>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { [weak handler] in handler?.stopRequested() }
            }, DarwinNotification.broadcastRequestStop.rawValue as CFString, nil, .deliverImmediately)
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
        frameCount = 0

        DarwinNotificationCenter.shared.postNotification(.broadcastStarted)
        openConnection()
    }

    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
    }

    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
    }

    deinit {
        connectionTimer?.cancel()
        CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque())
    }
    private func stopRequested() {
        guard !finishing else { return }
        finishing = true
        connectionTimer?.cancel()
        DarwinNotificationCenter.shared.postNotification(.broadcastStopped)
        clientConnection?.close()
        finishBroadcastWithError(NSError(domain: "Jospar.ScreenBroadcast", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Демонстрация экрана завершена"]))
    }
    override func broadcastFinished() {
        connectionTimer?.cancel()
        finishing = true
        // User has requested to finish the broadcast.
        DarwinNotificationCenter.shared.postNotification(.broadcastStopped)
        clientConnection?.close()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            uploader?.send(sample: sampleBuffer)
        default:
            break
        }
    }
}

private extension SampleHandler {

    func setupConnection() {
        clientConnection?.didClose = { [weak self] error in
            os_log(.debug, log: broadcastLogger, "client connection did close \(String(describing: error))")

            guard self?.finishing == false else { return }
            self?.finishing = true
            self?.connectionTimer?.cancel()
            if let error = error {
                self?.finishBroadcastWithError(error)
            } else {
                // the displayed failure message is more user friendly when using NSError instead of Error
                let JMScreenSharingStopped = 10001
                let customError = NSError(domain: RPRecordingErrorDomain, code: JMScreenSharingStopped, userInfo: [NSLocalizedDescriptionKey: "Screen sharing stopped"])
                self?.finishBroadcastWithError(customError)
            }
        }
    }

    func openConnection() {
        let queue = DispatchQueue(label: "broadcast.connectTimer")
        let timer = DispatchSource.makeTimerSource(queue: queue)
        connectionTimer = timer
        timer.schedule(deadline: .now(), repeating: .milliseconds(100), leeway: .milliseconds(500))
        timer.setEventHandler { [weak self] in
            guard self?.clientConnection?.open() == true else {
                return
            }

            timer.cancel()
        }

        timer.resume()
    }
}
