//
//  AudioEngine.swift
//  SwiftBeats
//
//  Created by Tyler Maxwell on 6/2/26.
//

import AVFoundation
import os.lock

@MainActor
public final class AudioEngine {
    private let engine     = AVAudioEngine()
    private var sourceNode : AVAudioSourceNode?
    private let reverbNode = AVAudioUnitReverb()
    private let delayNode  = AVAudioUnitDelay()

    private let pool = VoicePool()
    private var filterPtr: UnsafeMutablePointer<FourPoleFilter>?

    public let sampleRate: Double
    public var isRunning: Bool { engine.isRunning }

    public var filterCutoff: Double = 8000.0 {
        didSet { filterPtr?.pointee.cutoff = filterCutoff }
    }
    
    public var reverbMix: Float = 20.0 {
        didSet { reverbNode.wetDryMix = reverbMix.clamped(to: 0...100) }
    }
    
    public var delayFeedback: Double = 0.3 {
        didSet { delayNode.feedback = Float(delayFeedback.clamped(to: 0...1) * 100) }
    }
    
    public var delayMix: Double = 0.0 {
        didSet { delayNode.wetDryMix = Float(delayMix.clamped(to: 0...1) * 100) }
    }
    
    public var delayTime: Double = 0.25 {
        didSet { delayNode.delayTime = delayTime }
    }

    public var activeVoiceCount: Int { pool.activeVoiceCount }
    public var activeNotes: [Note] { pool.activeNotes }
    
    public var mixerNode: AVAudioMixerNode { engine.mainMixerNode }

    public init() {
        let hwRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        self.sampleRate = hwRate > 0 ? hwRate : 44100.0
    }

    deinit {
        filterPtr?.deinitialize(count: 1)
        filterPtr?.deallocate()
    }

    public func start() throws {
        guard !engine.isRunning else { return }

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        #endif

        let filter = UnsafeMutablePointer<FourPoleFilter>.allocate(capacity: 1)
        filter.initialize(to: FourPoleFilter(cutoff: filterCutoff, sampleRate: sampleRate))
        filterPtr = filter

        let sr = sampleRate
        let pool = self.pool
        let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2)!

        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            let abl   = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let count = Int(frameCount)

            for frame in 0..<count {
                var sample = pool.nextSample(sampleRate: sr)

                sample = filter.pointee.process(sample)
                sample = max(-1.0, min(1.0, sample))

                let s = Float(sample)
                for buffer in abl {
                    buffer.mData!.assumingMemoryBound(to: Float.self)[frame] = s
                }
            }
            
            return noErr
        }

        engine.attach(node)
        engine.attach(reverbNode)
        engine.attach(delayNode)
        engine.connect(node, to: reverbNode, format: format)
        engine.connect(reverbNode, to: delayNode, format: format)
        engine.connect(delayNode, to: engine.mainMixerNode, format: format)

        reverbNode.loadFactoryPreset(.mediumRoom)
        reverbNode.wetDryMix = reverbMix
        delayNode.delayTime = delayTime
        delayNode.feedback = Float(delayFeedback * 100)
        delayNode.wetDryMix = Float(delayMix * 100)

        engine.mainMixerNode.outputVolume = 1.0
        engine.prepare()
        try engine.start()
        sourceNode = node

        print("🎵 SwiftBeats v2 | \(Int(sr))Hz | \(VoicePool.maxVoices) voices | Filter + Reverb + Delay")
    }

    public func stop() {
        engine.stop()
        sourceNode = nil
    }

    public func noteOn(
        note: Note,
        waveform: Waveform  = .sine,
        envelope: Envelope  = .piano,
        velocity: Double    = 0.8,
        timbre: TimbrePreset = .none
    ) {
        pool.noteOn(note: note, waveform: waveform, envelope: envelope, velocity: velocity, timbre: timbre)
    }

    public func noteOff(note: Note) {
        pool.noteOff(note: note)
    }

    public func allNotesOff() {
        pool.allNotesOff()
    }

    public func scheduleNote(
        note: Note,
        waveform: Waveform  = .sine,
        envelope: Envelope  = .pluck,
        velocity: Double    = 0.8,
        duration: TimeInterval,
        timbre: TimbrePreset = .none
    ) {
        noteOn(note: note, waveform: waveform, envelope: envelope, velocity: velocity, timbre: timbre)

        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + duration) {
            [weak self] in self?.pool.noteOff(note: note)
        }
    }

    public func chord(
        notes: [Note],
        waveform: Waveform     = .sine,
        envelope: Envelope     = .pad,
        velocity: Double       = 0.7,
        duration: TimeInterval? = nil,
        timbre: TimbrePreset = .none
    ) {
        for note in notes {
            if let duration {
                scheduleNote(note: note, waveform: waveform, envelope: envelope,
                             velocity: velocity, duration: duration, timbre: timbre)
            } else {
                noteOn(note: note, waveform: waveform, envelope: envelope, velocity: velocity, timbre: timbre)
            }
        }
    }
}
