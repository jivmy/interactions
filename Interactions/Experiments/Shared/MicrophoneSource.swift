import AVFoundation
import Accelerate

/// RMS of the input tap. Permission is the system dialog; level is lock-published.
final class MicrophoneSource: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var smoothed: CGFloat = 0
    private var listening = false
    private var denied = false
    private var started = false
    private var tapInstalled = false

    var level: CGFloat {
        lock.lock()
        defer { lock.unlock() }
        return smoothed
    }

    var isListening: Bool {
        lock.lock()
        defer { lock.unlock() }
        return listening
    }

    var isDenied: Bool {
        lock.lock()
        defer { lock.unlock() }
        return denied
    }

    func start() {
        guard !started else { return }
        started = true
        Task { @MainActor [weak self] in
            let granted = await AVAudioApplication.requestRecordPermission()
            guard let self, self.started else { return }
            if granted {
                self.setDenied(false)
                self.beginEngine()
            } else {
                self.setDenied(true)
            }
        }
    }

    func stop() {
        started = false
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        if engine.isRunning {
            engine.stop()
        }
        lock.lock()
        listening = false
        smoothed = 0
        lock.unlock()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    deinit {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
        }
        if engine.isRunning {
            engine.stop()
        }
    }

    private func setDenied(_ value: Bool) {
        lock.lock()
        denied = value
        listening = false
        lock.unlock()
    }

    private func beginEngine() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                lock.lock()
                listening = false
                lock.unlock()
                return
            }
            if tapInstalled {
                input.removeTap(onBus: 0)
                tapInstalled = false
            }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.capture(buffer)
            }
            tapInstalled = true
            try engine.start()
            lock.lock()
            listening = true
            lock.unlock()
        } catch {
            lock.lock()
            listening = false
            lock.unlock()
        }
    }

    private func capture(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 16 else { return }

        var meanSquare: Float = 0
        vDSP_measqv(channel, 1, &meanSquare, vDSP_Length(frames))
        let rms = CGFloat(sqrt(Double(meanSquare)))

        lock.lock()
        smoothed += (rms - smoothed) * 0.28
        lock.unlock()
    }
}
