//
//  Voice.swift
//  SwiftBeats
//
//  Created by Tyler Maxwell on 6/2/26.
//

import Foundation

// MARK: - TimbrePreset

/// Describes the harmonic character of a voice beyond just waveform + envelope.
/// The partial ratio sets the frequency of a second oscillator relative to the
/// fundamental. 0.0 means no partial (off).
public struct TimbrePreset: Sendable {
    /// Frequency of the partial relative to the fundamental (0.0 = none)
    public let partialRatio: Double
    /// Amplitude of the partial relative to the fundamental (0.0–1.0)
    public let partialLevel: Double

    public init(partialRatio: Double, partialLevel: Double) {
        self.partialRatio = partialRatio
        self.partialLevel = partialLevel
    }

    public static let none       = TimbrePreset(partialRatio: 0.0,  partialLevel: 0.0)
    /// Vibraphone: inharmonic partial at 3.87x gives the metallic shimmer
    public static let vibraphone = TimbrePreset(partialRatio: 3.87, partialLevel: 0.25)
    /// Marimba: wooden bar — softer partial, lower ratio
    public static let marimba    = TimbrePreset(partialRatio: 3.93, partialLevel: 0.12)
    /// Bell: classic bell partial creates that slightly dissonant ring
    public static let bell       = TimbrePreset(partialRatio: 2.76, partialLevel: 0.4)
    /// Flute: second harmonic (octave) very quiet, adds breathiness
    public static let flute      = TimbrePreset(partialRatio: 2.0,  partialLevel: 0.08)
    /// Strings: rich harmonics — sawtooth wave handles this, but a slight
    /// partial at 1.5x (perfect fifth) adds warmth
    public static let strings    = TimbrePreset(partialRatio: 1.5,  partialLevel: 0.15)
}

// MARK: - Voice

/// A complete signal chain: (Oscillator + Partial) → Envelope → output sample.
public struct Voice: Sendable {

    // MARK: - Components

    public var oscillator: Oscillator       // fundamental
    private var partial: Oscillator         // harmonic overtone (may be silent)
    public var envelope: Envelope
    public var timbre: TimbrePreset

    // MARK: - State

    public private(set) var currentNote: Note?
    public var isActive: Bool { !envelope.isIdle }

    // MARK: - Init

    public init(
        waveform: Waveform = .sine,
        envelope: Envelope = .piano,
        timbre: TimbrePreset = .none
    ) {
        self.oscillator = Oscillator(waveform: waveform)
        self.partial    = Oscillator(waveform: .sine, amplitude: timbre.partialLevel)
        self.envelope   = envelope
        self.timbre     = timbre
    }

    // MARK: - Control

    public mutating func noteOn(_ note: Note, velocity: Double = 1.0) {
        currentNote = note
        oscillator.tune(to: note)
        oscillator.amplitude = velocity.clamped(to: 0.0...1.0)

        // Tune partial to the harmonic ratio above the fundamental
        if timbre.partialRatio > 0 {
            partial.frequency = note.frequency * timbre.partialRatio
            partial.amplitude = timbre.partialLevel * velocity
        }

        envelope.noteOn()
    }

    public mutating func noteOff() {
        envelope.noteOff()
    }

    public mutating func kill() {
        envelope.forceIdle()
        currentNote = nil
    }

    // MARK: - Sample generation

    public mutating func nextSample(sampleRate: Double) -> Double {
        guard isActive else { return 0.0 }
        let env = envelope.nextSample(sampleRate: sampleRate)
        var out = oscillator.nextSample(sampleRate: sampleRate)

        // Mix in the partial if active
        if timbre.partialRatio > 0 {
            out += partial.nextSample(sampleRate: sampleRate)
            // Normalise so total doesn't exceed 1.0
            out /= (1.0 + timbre.partialLevel)
        }

        return out * env
    }
}
