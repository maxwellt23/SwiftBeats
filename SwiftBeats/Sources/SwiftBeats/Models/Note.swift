//
//  Note.swift
//  SwiftBeats
//
//  Created by Tyler Maxwell on 6/2/26.
//

import Foundation

public enum Pitch: Int, CaseIterable, Sendable {
    case C = 0
    case Cs = 1 // C# / Db
    case D = 2
    case Ds = 3 // D# / Eb
    case E = 4
    case F = 5
    case Fs = 6 // F# / Gb
    case G = 7
    case Gs = 8 // G# / Ab
    case A = 9
    case As = 10 // A# / Bb
    case B = 11
    
    public var name: String {
        switch self {
        case .C: return "C"
        case .Cs: return "C#"
        case .D: return "D"
        case .Ds: return "D#"
        case .E: return "E"
        case .F: return "F"
        case .Fs: return "F#"
        case .G: return "G"
        case .Gs: return "G#"
        case .A: return "A"
        case .As: return "A#"
        case .B: return "B"
        }
    }
}

public struct Note: Equatable, Sendable {
    public let pitch: Pitch
    public let octave: Int
    
    public init(_ pitch: Pitch, octave: Int = 4) {
        self.pitch = pitch
        self.octave = octave
    }
    
    /// MIDI note number (0-127). Middle C = 60
    public var midiNumber: Int {
        (octave + 1) * 12 + pitch.rawValue
    }
    
    /// Frequency in Hz using equal temperament, A4 = 440 Hz.
    public var frequency: Double {
        let semitones = Double(midiNumber - 69)
        return 440.0 * pow(2.0, semitones / 12.0)
    }
    
    public var name: String { "\(pitch.name)\(octave)" }
}

// MARK: - Common Notes (static convenience)
public extension Note {
    static let C4  = Note(.C,  octave: 4)  // Middle C
    static let D4  = Note(.D,  octave: 4)
    static let E4  = Note(.E,  octave: 4)
    static let F4  = Note(.F,  octave: 4)
    static let G4  = Note(.G,  octave: 4)
    static let A4  = Note(.A,  octave: 4)  // A440
    static let B4  = Note(.B,  octave: 4)
    static let C5  = Note(.C,  octave: 5)
    static let A3  = Note(.A,  octave: 3)
    static let C3  = Note(.C,  octave: 3)
    static let G3  = Note(.G,  octave: 3)
}

public extension Note {
    static func fromMIDI(_ number: Int) -> Note? {
        guard (0...127).contains(number) else { return nil }
        
        let octave = (number / 12) - 1
        let pitchIndex = number % 12
        
        guard let pitch = Pitch(rawValue: pitchIndex) else { return nil }
        return Note(pitch, octave: octave)
    }
}

public struct Duration: Equatable {
    public let beats: Double
    
    public init(beats: Double) {
        self.beats = beats
    }
    
    public static let whole = Duration(beats: 4.0)
    public static let half = Duration(beats: 2.0)
    public static let quarter = Duration(beats: 1.0)
    public static let eighth = Duration(beats: 0.5)
    public static let sixteenth = Duration(beats: 0.25)
}

public enum Waveform: String, CaseIterable, Sendable {
    case sine
    case square
    case sawtooth
    case triangle
    
    public var description: String {
        switch self {
        case .sine: return "Sine (pure tone)"
        case .square: return "Square (hollow, buzzy)"
        case .sawtooth: return "Sawtooth (bright, harsh)"
        case .triangle: return "Triangle (soft, round)"
        }
    }
}
