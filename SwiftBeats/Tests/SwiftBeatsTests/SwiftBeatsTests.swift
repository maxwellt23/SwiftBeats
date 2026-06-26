import XCTest
@testable import SwiftBeats

// MARK: - Note Tests

final class NoteTests: XCTestCase {
    func testA4Frequency() {
        XCTAssertEqual(Note(.A, octave: 4).frequency, 440.0, accuracy: 0.001)
    }
    
    func testMiddleCFrequency() {
        XCTAssertEqual(Note.C4.frequency, 261.626, accuracy: 0.001)
    }
    
    func testOctaveDoubling() {
        XCTAssertEqual(Note(.C, octave: 5).frequency / Note.C4.frequency, 2.0, accuracy: 0.001)
    }
    
    func testMidiMiddleC() {
        XCTAssertEqual(Note.C4.midiNumber, 60)
    }
    
    func testMidiA4() {
        XCTAssertEqual(Note(.A, octave: 4).midiNumber, 69)
    }
    
    func testFromMidi() {
        let note = Note.fromMIDI(69)
        XCTAssertEqual(note?.pitch, .A)
        XCTAssertEqual(note?.octave, 4)
    }
}

// MARK: - Oscillator Tests

final class OscillatorTests: XCTestCase {
    let sr = 44100.0

    func testSineRange() {
        var osc = Oscillator(frequency: 440, waveform: .sine, amplitude: 0.8)
        for _ in 0..<Int(sr) {
            XCTAssertLessThanOrEqual(abs(osc.nextSample(sampleRate: sr)), 0.8001)
        }
    }

    func testSquareOnlyTwoValues() {
        var osc = Oscillator(frequency: 100, waveform: .square, amplitude: 1.0)
        for _ in 0..<1000 {
            let s = abs(osc.nextSample(sampleRate: sr))
            XCTAssertTrue(abs(s - 1.0) < 0.0001 || abs(s) < 0.0001)
        }
    }

    func testSawtoothRange() {
        var osc = Oscillator(frequency: 440, waveform: .sawtooth, amplitude: 1.0)
        for _ in 0..<Int(sr) {
            let s = osc.nextSample(sampleRate: sr)
            XCTAssertLessThanOrEqual(s,  1.001)
            XCTAssertGreaterThanOrEqual(s, -1.001)
        }
    }

    func testAmplitudeClamp() {
        XCTAssertEqual(Oscillator(frequency: 440, waveform: .sine, amplitude: 2.0).amplitude, 1.0)
    }
}

// MARK: - Envelope Tests

final class EnvelopeTests: XCTestCase {
    let sr = 44100.0

    func testStartsIdle() {
        XCTAssertTrue(Envelope().isIdle)
    }

    func testNoteOnActivates() {
        var env = Envelope(attack: 0.1, decay: 0.1, sustain: 0.7, release: 0.2)
        env.noteOn()
        XCTAssertGreaterThan(env.nextSample(sampleRate: sr), 0)
        XCTAssertFalse(env.isIdle)
    }

    func testReachesIdleAfterRelease() {
        var env = Envelope(attack: 0.001, decay: 0.001, sustain: 0.5, release: 0.001)
        env.noteOn()
        for _ in 0..<200 { _ = env.nextSample(sampleRate: sr) }
        env.noteOff()
        var i = 0
        while !env.isIdle && i < 10000 { _ = env.nextSample(sampleRate: sr); i += 1 }
        XCTAssertTrue(env.isIdle)
    }

    func testOutputClampedToOne() {
        var env = Envelope(attack: 0.01, decay: 0.01, sustain: 0.8, release: 0.01)
        env.noteOn()
        for _ in 0..<5000 {
            let s = env.nextSample(sampleRate: sr)
            XCTAssertLessThanOrEqual(s, 1.0001)
            XCTAssertGreaterThanOrEqual(s, 0)
        }
    }
}

// MARK: - VoicePool Tests

final class VoicePoolTests: XCTestCase {
    let sr = 44100.0

    func testStartsSilent() {
        let pool = VoicePool()
        XCTAssertEqual(pool.activeVoiceCount, 0)
        XCTAssertEqual(pool.nextSample(sampleRate: sr), 0.0)
    }

    func testNoteOnActivatesVoice() {
        let pool = VoicePool()
        pool.noteOn(note: .A4, waveform: .sine, envelope: .pluck, velocity: 0.8)
        XCTAssertEqual(pool.activeVoiceCount, 1)
    }

    func testPolyphony() {
        let pool = VoicePool()
        pool.noteOn(note: .C4, waveform: .sine, envelope: .organ, velocity: 0.8)
        pool.noteOn(note: .E4, waveform: .sine, envelope: .organ, velocity: 0.8)
        pool.noteOn(note: .G4, waveform: .sine, envelope: .organ, velocity: 0.8)
        XCTAssertEqual(pool.activeVoiceCount, 3)
    }

    func testMaxVoicesNotExceeded() {
        let pool = VoicePool()
        let notes: [Note] = [.C4, .D4, .E4, .F4, .G4, .A4, .B4, .C5,
                             Note(.D, octave: 5), Note(.E, octave: 5)]
        for note in notes {
            pool.noteOn(note: note, waveform: .sine, envelope: .organ, velocity: 0.8)
        }
        XCTAssertLessThanOrEqual(pool.activeVoiceCount, VoicePool.maxVoices)
    }

    func testAllNotesOff() {
        let pool = VoicePool()
        pool.noteOn(note: .C4, waveform: .sine, envelope: .organ, velocity: 0.8)
        pool.noteOn(note: .E4, waveform: .sine, envelope: .organ, velocity: 0.8)
        pool.allNotesOff()
        // After kill(), voices are idle immediately
        XCTAssertEqual(pool.activeVoiceCount, 0)
    }

    func testOutputScalesWithVoiceCount() {
        let poolOne = VoicePool()
        let poolThree = VoicePool()
        poolOne.noteOn(note: .A4, waveform: .sine, envelope: .organ, velocity: 1.0)
        poolThree.noteOn(note: .A4, waveform: .sine, envelope: .organ, velocity: 1.0)
        poolThree.noteOn(note: .C4, waveform: .sine, envelope: .organ, velocity: 1.0)
        poolThree.noteOn(note: .E4, waveform: .sine, envelope: .organ, velocity: 1.0)

        // Both should stay within [-1, 1]
        for _ in 0..<1000 {
            XCTAssertLessThanOrEqual(abs(poolOne.nextSample(sampleRate: sr)), 1.01)
            XCTAssertLessThanOrEqual(abs(poolThree.nextSample(sampleRate: sr)), 1.01)
        }
    }
}

// MARK: - Filter Tests

final class FilterTests: XCTestCase {
    let sr = 44100.0

    func testPassesDCComponent() {
        // A DC signal (constant value) should pass through a LPF at full amplitude
        var filter = OnePoleFilter(cutoff: 20000, sampleRate: sr)
        var output = 0.0
        for _ in 0..<1000 { output = filter.process(1.0) }
        XCTAssertGreaterThan(output, 0.99)
    }

    func testAttenuatesHighFreq() {
        // With a very low cutoff, a high-freq signal should be strongly attenuated
        var filter = OnePoleFilter(cutoff: 100, sampleRate: sr)
        var osc = Oscillator(frequency: 10000, waveform: .sine, amplitude: 1.0)
        var maxOut = 0.0
        for _ in 0..<Int(sr) {
            let sample = osc.nextSample(sampleRate: sr)
            let filtered = filter.process(sample)
            maxOut = max(maxOut, abs(filtered))
        }
        // 10kHz through a 100Hz filter should be very quiet
        XCTAssertLessThan(maxOut, 0.1)
    }

    func testFourPoleSteeperThanOnePole() {
        let testFreq = 5000.0
        let cutoff = 1000.0

        var one = OnePoleFilter(cutoff: cutoff, sampleRate: sr)
        var four = FourPoleFilter(cutoff: cutoff, sampleRate: sr)
        var osc1 = Oscillator(frequency: testFreq, waveform: .sine, amplitude: 1.0)
        var osc2 = Oscillator(frequency: testFreq, waveform: .sine, amplitude: 1.0)

        var maxOne = 0.0, maxFour = 0.0
        for _ in 0..<Int(sr) {
            maxOne = max(maxOne, abs(one.process(osc1.nextSample(sampleRate: sr))))
            maxFour = max(maxFour, abs(four.process(osc2.nextSample(sampleRate: sr))))
        }
        // 4-pole should attenuate more than 1-pole
        XCTAssertLessThan(maxFour, maxOne)
    }
}

// MARK: - Sequence Tests

final class SequenceTests: XCTestCase {
    func testCMajorScaleLength() {
        XCTAssertEqual(Sequence.cMajorScale.steps.count, 8)
    }
    
    func testPentatonicHasRests() {
        XCTAssertTrue(Sequence.pentatonicMelody.steps.contains { $0.note == nil })
    }
    
    func testCustomSequence() {
        let seq = Sequence.from(notes: [.A4, nil, .C5], waveform: .triangle)
        XCTAssertEqual(seq.steps.count, 3)
        XCTAssertNil(seq.steps[1].note)
        XCTAssertEqual(seq.steps[0].waveform, .triangle)
    }
}
