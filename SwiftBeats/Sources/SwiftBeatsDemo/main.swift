//
//  main.swift
//  SwiftBeats
//
//  Created by Tyler Maxwell on 6/2/26.
//

import Foundation
import SwiftBeats

print("""
╔══════════════════════════════════════╗
║     🎵 SwiftBeats v2 Demo            ║
║     Polyphony · Filter · Reverb      ║
╚══════════════════════════════════════╝
""")

Task { @MainActor in
    do {
        let engine = try SwiftBeats()
        print("✅ Engine started\n")
        func sleep(_ ms: Int) async throws {
            try await Task.sleep(for: .milliseconds(ms))
        }

        // ── Demo 1: Polyphonic chord ──────────────────────────────────────
        print("📌 Demo 1: Polyphonic chord (C major triad)")
        engine.chord([.C4, .E4, .G4], waveform: .sine, envelope: .pad, duration: 2.0)
        try await sleep(2500)

        // ── Demo 2: Chord progression ─────────────────────────────────────
        print("\n📌 Demo 2: I–V–vi–IV chord progression")
        let progression: [(Note, String)] = [
            (Note(.C, octave: 3), "C major"),
            (Note(.G, octave: 3), "G major"),
            (Note(.A, octave: 3), "A minor"),
            (Note(.F, octave: 3), "F major"),
        ]
        for (root, name) in progression {
            let isMinor = name.contains("minor")
            let notes = isMinor ? SwiftBeats.minorChord(root: root) : SwiftBeats.majorChord(root: root)
            print("  \(name): \(notes.map(\.name).joined(separator: " "))")
            engine.chord(notes, waveform: .sawtooth, envelope: .pad, duration: 1.6)
            try await sleep(2000)
        }

        // ── Demo 3: Filter sweep ──────────────────────────────────────────
        print("\n📌 Demo 3: Filter cutoff sweep on sawtooth chord")
        engine.chord([.C3, .G3, .C4], waveform: .sawtooth, envelope: .organ)
        engine.filterCutoff = 200
        print("  Sweeping filter from 200Hz → 8000Hz...")
        for hz in stride(from: 200.0, through: 8000.0, by: 100.0) {
            engine.filterCutoff = hz
            try await sleep(15)
        }
        engine.allNotesOff()
        try await sleep(500)

        // ── Demo 4: Reverb ────────────────────────────────────────────────
        print("\n📌 Demo 4: Reverb (dry → wet)")
        engine.reverbMix = 0
        engine.filterCutoff = 8000
        for mix: Float in [0, 20, 50, 80] {
            engine.reverbMix = mix
            print("  Reverb mix: \(mix)%")
            engine.play(.C4, waveform: .triangle, envelope: .pluck, duration: 0.1)
            try await sleep(800)
        }
        engine.reverbMix = 20
        try await sleep(300)

        // ── Demo 5: Delay ─────────────────────────────────────────────────
        print("\n📌 Demo 5: Delay effect")
        engine.delayTime = 0.3
        engine.delayMix = 0.4
        engine.delayFeedback = 0.4
        print("  Delay: 300ms, 40% mix, 40% feedback")
        for note in [Note.C4, .E4, .G4, .C5] {
            engine.play(note, waveform: .triangle, envelope: .pluck, duration: 0.05)
            try await sleep(400)
        }
        engine.delayMix = 0
        try await sleep(1000)

        // ── Demo 6: Sequencer ─────────────────────────────────────────────
        print("\n📌 Demo 6: Fixed sequencer — C major scale at 130 BPM")
        engine.reverbMix = 15
        engine.filterCutoff = 6000
        engine.play(.cMajorScale, bpm: 130)
        try await sleep(5000)
        engine.stop()
        try await sleep(300)

        // ── Demo 7: Full combo ────────────────────────────────────────────
        print("\n📌 Demo 7: Chord progression with reverb + delay")
        engine.reverbMix = 30
        engine.delayMix = 0.2
        engine.delayTime = 0.375  // dotted eighth at 120bpm
        engine.delayFeedback = 0.3
        engine.play(.chordProgression, bpm: 110)
        try await sleep(8000)
        engine.stop()

        print("\n✅ v2 Demo complete!")
        engine.allNotesOff()
        engine.stop()

    } catch {
        print("❌ Error: \(error)")
    }
    exit(0)
}

RunLoop.main.run()
