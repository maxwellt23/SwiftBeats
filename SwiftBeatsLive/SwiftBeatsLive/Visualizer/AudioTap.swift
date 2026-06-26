//
//  AudioTap.swift
//  SwiftBeatsLive
//
//  Created by Tyler Maxwell on 6/3/26.
//

import AVFoundation
import Accelerate
import SwiftBeats
import QuartzCore

// MARK: - RingBuffer

final class RingBuffer {
    private let capacity: Int
    private var buffer: [Float]
    private var writeHead: Int = 0

    init(capacity: Int = 16384) {
        self.capacity = capacity
        self.buffer   = Array(repeating: 0, count: capacity)
    }

    func write(_ samples: UnsafePointer<Float>, count: Int) {
        for i in 0..<count {
            buffer[writeHead] = samples[i]
            writeHead = (writeHead + 1) % capacity
        }
    }

    func readRecent(count: Int) -> [Float] {
        let n    = min(count, capacity)
        let head = writeHead
        return (0..<n).map { i in buffer[(head - n + i + capacity) % capacity] }
    }
}

// MARK: - AudioTap

@MainActor
final class AudioTap {

    private let ringBuffer = RingBuffer()

    // FFT config
    private let fftSize = 1024                         // must be power of two
    private let fft: vDSP.FFT<DSPSplitComplex>

    // Pre-allocated buffers
    private var window:     [Float]
    private var windowed:   [Float]                    // windowed input (real)
    private var realOut:    [Float]                    // FFT real output
    private var imagOut:    [Float]                    // FFT imaginary output
    private var magnitudes: [Float]                    // magnitude² per bin

    // Normalisation: after a forward FFT on N real samples, a full-scale
    // sine produces peak magnitude² ≈ (N/2)². We normalise by (N/2)² so
    // a full-scale signal maps to 0 dB.
    private let normFactor: Float

    init(engine: AudioEngine) {
        let log2n = vDSP_Length(log2(Float(1024)))
        fft = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self)!

        window     = [Float](repeating: 0, count: 1024)
        windowed   = [Float](repeating: 0, count: 1024)
        realOut    = [Float](repeating: 0, count: 1024)
        imagOut    = [Float](repeating: 0, count: 1024)
        magnitudes = [Float](repeating: 0, count: 512)

        // Full-scale sine peak magnitude² after 1024-point FFT ≈ (512)² = 262144
        normFactor = Float(512 * 512)

        vDSP_hann_window(&window, vDSP_Length(1024), Int32(vDSP_HANN_NORM))

        installTap(on: engine)
    }

    // MARK: - Tap

    private func installTap(on audioEngine: AudioEngine) {
        let format = audioEngine.mixerNode.outputFormat(forBus: 0)
        audioEngine.mixerNode.installTap(onBus: 0, bufferSize: 512, format: format) {
            [weak self] buffer, _ in
            guard let self,
                  let data = buffer.floatChannelData?[0] else { return }
            self.ringBuffer.write(data, count: Int(buffer.frameLength))
        }
    }

    // MARK: - Snapshots

    func oscilloscopeSnapshot(count: Int) -> [Float] {
        ringBuffer.readRecent(count: count)
    }

    func spectrumSnapshot(binCount: Int) -> [Float] {
        // 1. Grab samples and apply Hann window into a separate buffer
        let samples = ringBuffer.readRecent(count: fftSize)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        // 2. Forward FFT — use SEPARATE input and output buffers.
        //    Aliasing input == output is undefined behaviour with vDSP.FFT.
        windowed.withUnsafeMutableBufferPointer { wPtr in
            realOut.withUnsafeMutableBufferPointer { rPtr in
                imagOut.withUnsafeMutableBufferPointer { iPtr in
                    // Pack real-only input as split complex (imaginary = 0)
                    var zeroImag = [Float](repeating: 0, count: fftSize)
                    var inputSplit  = DSPSplitComplex(realp: wPtr.baseAddress!,
                                                      imagp: &zeroImag)
                    var outputSplit = DSPSplitComplex(realp: rPtr.baseAddress!,
                                                      imagp: iPtr.baseAddress!)
                    fft.forward(input: inputSplit, output: &outputSplit)
                }
            }
        }

        // 3. Compute magnitude² for bins 0..<N/2
        realOut.withUnsafeMutableBufferPointer { rPtr in
            imagOut.withUnsafeMutableBufferPointer { iPtr in
                var split = DSPSplitComplex(realp: rPtr.baseAddress!,
                                            imagp: iPtr.baseAddress!)
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        // 4. Normalise by (N/2)² so full-scale signal = 1.0 in linear domain
        var norm = normFactor
        vDSP_vsdiv(magnitudes, 1, &norm, &magnitudes, 1, vDSP_Length(fftSize / 2))

        // 5. Convert normalised power to dB: 10*log10(x)
        //    Full-scale → 0 dB.  Silence → very negative dB.
        var dbMags = [Float](repeating: 0, count: fftSize / 2)
        var one: Float = 1.0
        vDSP_vdbcon(magnitudes, 1, &one, &dbMags, 1, vDSP_Length(fftSize / 2), 0)

        // 6. Map to log-frequency scale
        return logScaleBins(dbMags, outputCount: binCount)
    }

    // MARK: - Log-scale mapping

    private func logScaleBins(_ bins: [Float], outputCount: Int) -> [Float] {
        let inputCount = bins.count

        // dB range: -60 dB (near-silence) to 0 dB (full scale).
        // Noise gate at -50 dB — anything quieter is drawn as zero.
        // This eliminates the "always maxed" look from FFT numerical noise.
        let floor:   Float = -60.0
        let gate:    Float = -50.0
        let ceiling: Float =   0.0

        return (0..<outputCount).map { i in
            // Logarithmic frequency mapping — clusters bins at low end
            let t      = Double(i) / Double(outputCount - 1)
            let logPos = pow(Double(inputCount - 1), t)
            let idx    = min(Int(logPos.rounded()), inputCount - 1)
            let db     = bins[idx]

            guard db > gate else { return Float(0) }
            return max(0, min(1, (db - floor) / (ceiling - floor)))
        }
    }
}

// MARK: - DisplayLinkDriver

final class DisplayLinkDriver {

    private var timer: Timer?
    private let callback: @MainActor () -> Void

    init(callback: @escaping @MainActor () -> Void) {
        self.callback = callback
        start()
    }

    deinit { stop() }

    private func start() {
        let t = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) {
            [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.callback() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }
}
