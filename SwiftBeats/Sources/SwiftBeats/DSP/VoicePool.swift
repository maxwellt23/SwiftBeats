//
//  VoicePool.swift
//  SwiftBeats
//
//  Created by Tyler Maxwell on 6/2/26.
//

import Foundation
import os.lock

public final class VoicePool {
    public static let maxVoices = 8

    private var lock = os_unfair_lock()

    private var voices: [Voice]
    private var voiceAges: [Int]
    private var globalAge: Int = 0

    public init() {
        voices = Array(repeating: Voice(), count: VoicePool.maxVoices)
        voiceAges = Array(repeating: 0, count: VoicePool.maxVoices)
    }

    @discardableResult
    public func noteOn(
        note: Note,
        waveform: Waveform,
        envelope: Envelope,
        velocity: Double,
        timbre: TimbrePreset = .none
    ) -> Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        let idx = selectVoice(for: note)
        
        globalAge += 1
        voiceAges[idx] = globalAge
        voices[idx].oscillator.waveform = waveform
        voices[idx].envelope = envelope
        voices[idx].timbre = timbre
        voices[idx].noteOn(note, velocity: velocity)
        
        return idx
    }

    public func noteOff(note: Note) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        for i in voices.indices where voices[i].currentNote == note {
            voices[i].noteOff()
        }
    }

    public func allNotesOff() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        for i in voices.indices {
            voices[i].kill()
        }
    }
    
    public func nextSample(sampleRate: Double) -> Double {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        var sum = 0.0
        var activeCount = 0

        for i in voices.indices {
            if voices[i].isActive {
                sum += voices[i].nextSample(sampleRate: sampleRate)
                activeCount += 1
            }
        }

        guard activeCount > 0 else { return 0.0 }
        return sum / Double(activeCount)
    }

    public var activeVoiceCount: Int {
        voices.filter { $0.isActive }.count
    }

    public var activeNotes: [Note] {
        voices.compactMap { $0.isActive ? $0.currentNote : nil }
    }

    private func selectVoice(for note: Note) -> Int {
        // 1. Re-trigger if already playing
        for i in voices.indices where voices[i].currentNote == note { return i }
        
        // 2. Idle voice
        for i in voices.indices where !voices[i].isActive { return i }
        
        // 3. Steal oldest
        return voiceAges.enumerated().min(by: { $0.element < $1.element })!.offset
    }
}
