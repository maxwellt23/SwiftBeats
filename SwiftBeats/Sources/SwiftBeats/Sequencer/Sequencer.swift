//
//  Sequencer.swift
//  SwiftBeats
//
//  Created by Tyler Maxwell on 6/2/26.
//

import Foundation
import AVFoundation

public struct Step: Sendable {
    public let note: Note?
    public let duration: Duration
    public let velocity: Double
    public let waveform: Waveform
    public let envelope: Envelope
    public let timbre: TimbrePreset
    /// Extra notes fired simultaneously with `note` to form a chord step.
    public let chordNotes: [Note]?

    public init(
        note: Note?,
        duration: Duration = .quarter,
        velocity: Double = 0.8,
        waveform: Waveform = .sine,
        envelope: Envelope = .pluck,
        timbre: TimbrePreset = .none,
        chordNotes: [Note]? = nil
    ) {
        self.note       = note
        self.duration   = duration
        self.velocity   = velocity
        self.waveform   = waveform
        self.envelope   = envelope
        self.timbre = timbre
        self.chordNotes = chordNotes
    }

    /// All notes this step will play (root + any chord members).
    public var allNotes: [Note] {
        guard let root = note else { return [] }
        if let extras = chordNotes { return extras }
        return [root]
    }

    public static func rest(duration: Duration = .quarter) -> Step {
        Step(note: nil, duration: duration)
    }
}

public struct Sequence {
    public let steps: [Step]
    public var name: String
    
    public init(name: String = "Sequence", steps: [Step]) {
        self.steps = steps
        self.name = name
    }
    
    public static func from(
        notes: [Note?],
        duration: Duration = .quarter,
        waveform: Waveform = .sine,
        envelope: Envelope = .pluck
    ) -> Sequence {
        let steps = notes.map { note in
            Step(note: note, duration: duration, waveform: waveform, envelope: envelope)
        }
        
        return Sequence(steps: steps)
    }
    
    // MARK: - Built-in demo sequences
    /// A classic C major scale
    public static let cMajorScale = Sequence.from(
        notes: [.C4, .D4, .E4, .F4, .G4, .A4, .B4, .C5],
        duration: .quarter,
        waveform: .sine,
        envelope: .pluck
    )
 
    /// A simple pentatonic melody
    public static let pentatonicMelody = Sequence.from(
        notes: [.C4, .E4, .G4, .A4, nil, .G4, .E4, .C4],
        duration: .eighth,
        waveform: .triangle,
        envelope: .pluck
    )
 
    /// A bass arpeggio
    public static let bassArpeggio = Sequence.from(
        notes: [
            Note(.C, octave: 2),
            Note(.G, octave: 2),
            Note(.C, octave: 3),
            Note(.E, octave: 3)
        ],
        duration: .eighth,
        waveform: .sawtooth,
        envelope: .pluck
    )
    
    public static let chordProgression: Sequence = {
        let notes: [Note?] = [
            Note(.C, octave: 3), nil,
            Note(.G, octave: 3), nil,
            Note(.A, octave: 3), nil,
            Note(.F, octave: 3), nil,
        ]
        return Sequence.from(notes: notes, duration: .eighth, waveform: .sawtooth, envelope: .pad)
    }()
}

struct ScheduledEvent {
    let step: Step
    let audioTime: AVAudioTime
    let releaseTime: AVAudioTime
}

@MainActor
public final class Sequencer {
    public var bpm: Double {
        didSet {
            sixteenthDuration = Self.sixteenthSeconds(bpm: bpm)
        }
    }
    
    public private(set) var isPlaying = false
    public private(set) var currentStep = 0
    
    public var onStepChange: ((Int, Step) -> Void)?
    
    private var sequence: Sequence?
    private let engine: AudioEngine
    
    private var clock: DispatchSourceTimer?
    private let clockQueue = DispatchQueue(label: "com.swiftbeats.clock", qos: .userInteractive)
    
    private var ticksRemainingInStep: Int = 0
    private var sixteenthDuration: TimeInterval
    
    public init(engine: AudioEngine, bpm: Double = 120.0) {
        self.engine = engine
        self.bpm = bpm
        self.sixteenthDuration = Self.sixteenthSeconds(bpm: bpm)
    }
    
    public func play(_ sequence: Sequence) {
        stop()
        self.sequence = sequence
        currentStep = 0
        isPlaying = true
        
        ticksRemainingInStep = ticks(for: sequence.steps[0])
        
        print("Playing '\(sequence.name)' at \(Int(bpm)) BPM")
        
        fire(sequence.steps[0], stepIndex: 0)
        
        startClock()
    }
    
    public func stop() {
        isPlaying = false
        clock?.cancel()
        clock = nil
        engine.allNotesOff()
        currentStep = 0
        ticksRemainingInStep = 0
    }
    
    public func pause() {
        isPlaying = false
        clock?.cancel()
        clock = nil
        engine.allNotesOff()
    }
    
    public func resume() {
        guard let sequence, !isPlaying else { return }
        
        isPlaying = true
        fire(sequence.steps[currentStep], stepIndex: currentStep)
        startClock()
    }
    
    private func startClock() {
        let timer = DispatchSource.makeTimerSource(queue: clockQueue)
        let intervalNs = UInt64(sixteenthDuration * 1_000_000_000)
        
        timer.schedule(
            deadline: .now() + sixteenthDuration,
            repeating: .nanoseconds(Int(intervalNs)),
            leeway: .microseconds(100)
        )
        
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        
        timer.resume()
        clock = timer
    }
    
    private func tick() {
        guard isPlaying, let sequence else { return }
        
        ticksRemainingInStep -= 1
        
        if ticksRemainingInStep <= 0 {
            let nextStep = (currentStep + 1) % sequence.steps.count
            let step = sequence.steps[nextStep]
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                self.currentStep = nextStep
                self.onStepChange?(nextStep, step)
                self.fire(step, stepIndex: nextStep)
            }
            
            ticksRemainingInStep = ticks(for: step)
        }
    }
    
    private func fire(_ step: Step, stepIndex: Int) {
        let beatsPerSecond = bpm / 60.0
        let stepSeconds    = step.duration.beats / beatsPerSecond
        let noteDuration   = stepSeconds * 0.8  // 80% note, 20% gap

        let notes = step.allNotes
        if notes.isEmpty {
            // Rest — don't call allNotesOff here because other sequencer
            // layers should keep playing through this layer's rest.
            print("  [\(stepIndex + 1)] rest")
        } else {
            // Fire every note in the step simultaneously.
            // Single notes produce one entry; chord steps produce several.
            // All share the same duration so they gate off together.
            engine.chord(
                notes: notes,
                waveform: step.waveform,
                envelope: step.envelope,
                velocity: step.velocity,
                duration: noteDuration,
                timbre: step.timbre
            )
            let label = notes.map(\.name).joined(separator: "+")
            print("  [\(stepIndex + 1)] \(label)")
        }
    }
    
    private func ticks(for step: Step) -> Int {
        max(1, Int(step.duration.beats * 4))
    }
    
    private static func sixteenthSeconds(bpm: Double) -> TimeInterval {
        (60.0 / bpm) / 4.0
    }
}
