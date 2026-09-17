import AVFoundation
import Accelerate
import Combine

/// Microphone tap + vDSP FFT. Dominant frequency in Hz and a coarse magnitude spectrum.
final class MicrophoneFFT: ObservableObject {
    @Published private(set) var dominantHz: Double = 0
    @Published private(set) var amplitude: Double = 0
    @Published private(set) var bins: [Float] = Array(repeating: 0, count: 48)
    @Published private(set) var isListening = false
    @Published private(set) var denied = false

    private let engine = AVAudioEngine()
    private var fftSetup: FFTSetup?
    private let log2n: vDSP_Length = 11
    private var n: Int { 1 << Int(log2n) }
    private var window: [Float] = []
    private var started = false
    private let lock = NSLock()
    private var latestBins: [Float] = Array(repeating: 0, count: 48)
    private var latestHz: Double = 0
    private var latestAmp: Double = 0

    func start() {
        guard !started else { return }
        started = true
        Task { @MainActor [weak self] in
            let granted = await AVAudioApplication.requestRecordPermission()
            guard let self, self.started else { return }
            if granted {
                self.denied = false
                self.beginEngine()
            } else {
                self.denied = true
                self.isListening = false
            }
        }
    }

    func stop() {
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        if let fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
            self.fftSetup = nil
        }
        started = false
        isListening = false
    }

    /// Pull published values onto the main-thread experiment tick.
    func publish() {
        lock.lock()
        let bins = latestBins
        let hz = latestHz
        let amp = latestAmp
        lock.unlock()
        self.bins = bins
        dominantHz = hz
        amplitude = amp
    }

    private func beginEngine() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                isListening = false
                return
            }
            window = [Float](repeating: 0, count: n)
            vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
            fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(n), format: format) { [weak self] buffer, _ in
                self?.analyze(buffer: buffer, sampleRate: format.sampleRate)
            }
            try engine.start()
            isListening = true
        } catch {
            isListening = false
        }
    }

    private func analyze(buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let channel = buffer.floatChannelData?[0], let fftSetup else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 32 else { return }

        var samples = [Float](repeating: 0, count: n)
        let copyCount = min(frames, n)
        samples.withUnsafeMutableBufferPointer { dest in
            dest.baseAddress?.update(from: channel, count: copyCount)
        }
        vDSP_vmul(samples, 1, window, 1, &samples, 1, vDSP_Length(n))

        var real = [Float](repeating: 0, count: n / 2)
        var imag = [Float](repeating: 0, count: n / 2)
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                samples.withUnsafeBufferPointer { src in
                    src.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: n / 2) { complex in
                        vDSP_ctoz(complex, 2, &split, 1, vDSP_Length(n / 2))
                    }
                }
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                var magnitudes = [Float](repeating: 0, count: n / 2)
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(n / 2))
                var nyquist = imagPtr.baseAddress![0]
                magnitudes[0] = realPtr.baseAddress![0] * realPtr.baseAddress![0]
                if magnitudes.count > 1 {
                    magnitudes[n / 2 - 1] = nyquist * nyquist
                }

                var binCount = 48
                var coarse = [Float](repeating: 0, count: binCount)
                let usable = min(magnitudes.count - 1, 400)
                for i in 0..<binCount {
                    let start = 1 + i * usable / binCount
                    let end = 1 + (i + 1) * usable / binCount
                    var sum: Float = 0
                    for k in start..<max(start + 1, end) where k < magnitudes.count {
                        sum += magnitudes[k]
                    }
                    coarse[i] = sqrt(sum / Float(max(1, end - start)))
                }

                var peakIndex: vDSP_Length = 0
                var peak: Float = 0
                let hi = min(magnitudes.count - 1, max(8, Int(2000 / (sampleRate / Double(n)))))
                let span = max(1, hi - 2)
                vDSP_maxvi(Array(magnitudes[2..<hi]), 1, &peak, &peakIndex, vDSP_Length(span))
                let idx = Int(peakIndex) + 2
                let hz = Double(idx) * sampleRate / Double(n)
                var amp: Float = 0
                vDSP_sve(coarse, 1, &amp, vDSP_Length(binCount))

                self.lock.lock()
                self.latestBins = coarse
                self.latestHz = hz
                self.latestAmp = Double(amp / Float(binCount))
                self.lock.unlock()
            }
        }
    }
}
