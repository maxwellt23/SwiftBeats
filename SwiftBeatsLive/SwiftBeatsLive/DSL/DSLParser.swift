//
//  DSLParser.swift
//  SwiftBeatsLive
//
//  Created by Tyler Maxwell on 6/3/26.
//

import Foundation
import SwiftBeats

struct SequenceLineInfo {
    let lineIndex: Int
    let lineCharRange: NSRange
    let stepCount: Int
    let noteCharRanges: [NSRange]
}

private struct LineContext {
    let lineIndex: Int
    let utf16Offset: Int
    let utf16Length: Int
    let nsFullText: NSString
}

struct ParseInfo {
    let description: String
    let stepCount: Int
    let sequences: [SequenceLineInfo]

    init(description: String, stepCount: Int = 0, sequences: [SequenceLineInfo] = []) {
        self.description = description
        self.stepCount = stepCount
        self.sequences = sequences
    }
}

enum DSLError: LocalizedError {
    case noValidCommands
    case unknownCommand(String)
    case invalidNote(String)
    case missingArgument(String)
    
    var errorDescription: String? {
        switch self {
        case .noValidCommands:
            return "No valid commands found. Try: play C4 or sequence [C4 E4 G4]"
        case .unknownCommand(let cmd):
            return "Unknown command '\(cmd)'. Try: play, chord, sequence, reverb, filter, delay, stop"
        case .invalidNote(let n):
            return "'\(n)' isn't a note I recognize. Try something like C4, D#3, or Eb5"
        case .missingArgument(let cmd):
            return "'\(cmd)' needs at least one note. Example: \(cmd) C4 E4 G4"
        }
    }
}

final class DSLParser {
    private let engine: SwiftBeats
    private(set) var lastErrorLineIndex: Int? = nil

    init(engine: SwiftBeats) {
        self.engine = engine
    }
    
    func execute(_ text: String) -> Result<ParseInfo, DSLError> {
        let nsText = text as NSString
        let rawLines = text.components(separatedBy: "\n")

        // Compute UTF-16 line offsets for NSRange-based highlighting
        var utf16Offset = 0
        var lineUTF16Offsets: [Int] = []
        for line in rawLines {
            lineUTF16Offsets.append(utf16Offset)
            utf16Offset += (line as NSString).length + 1
        }

        var executedCount = 0
        var lastInfo = ParseInfo(description: "Running")
        var firstError: DSLError?
        var firstErrorLine: Int?
        var allSequences: [SequenceLineInfo] = []

        for (lineIdx, rawLine) in rawLines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty && !trimmed.hasPrefix("//") else { continue }

            let ctx = LineContext(
                lineIndex: lineIdx,
                utf16Offset: lineUTF16Offsets[lineIdx],
                utf16Length: (rawLine as NSString).length,
                nsFullText: nsText
            )

            switch executeLine(trimmed, ctx: ctx) {
            case .success(let info):
                executedCount += 1
                lastInfo = info
                allSequences.append(contentsOf: info.sequences)
            case .failure(let err):
                if firstError == nil {
                    firstError = err
                    firstErrorLine = lineIdx
                }
            }
        }

        // Always expose the first bad line index (even on partial success, so the editor can flag it)
        lastErrorLineIndex = firstErrorLine

        if executedCount == 0, let error = firstError {
            return .failure(error)
        }

        let totalSteps = allSequences.first?.stepCount ?? lastInfo.stepCount
        return .success(ParseInfo(
            description: lastInfo.description,
            stepCount: totalSteps,
            sequences: allSequences
        ))
    }
    
    private func executeLine(_ line: String, ctx: LineContext) -> Result<ParseInfo, DSLError> {
        let tokens = tokenise(line)
        guard let command = tokens.first?.lowercased() else {
            return .failure(.noValidCommands)
        }

        switch command {
        case "play":
            return executePlay(tokens: Array(tokens.dropFirst()))
        case "chord":
            return executeChord(tokens: Array(tokens.dropFirst()))
        case "sequence", "seq":
            return executeSequence(tokens: Array(tokens.dropFirst()), ctx: ctx)
        case "reverb":
            return executeReverb(tokens: Array(tokens.dropFirst()))
        case "filter":
            return executeFilter(tokens: Array(tokens.dropFirst()))
        case "delay":
            return executeDelay(tokens: Array(tokens.dropFirst()))
        case "tempo", "bpm":
            return executeTempo(tokens: Array(tokens.dropFirst()))
        case "stop":
            engine.stop()
            engine.allNotesOff()
            return .success(ParseInfo(description: "Stopped"))
        default:
            if let note = parseNote(command) {
                let notes = tokens.compactMap { parseNote($0) }
                let all = [note] + notes
                engine.chord(all, waveform: .sine, duration: 1.0)
                return .success(ParseInfo(description: "Playing \(all.map(\.name).joined(separator: " "))"))
            }
            return .failure(.unknownCommand(command))
        }
    }
    
    private func executePlay(tokens: [String]) -> Result<ParseInfo, DSLError> {
        guard !tokens.isEmpty else { return .failure(.missingArgument("play")) }
        
        let notes = tokens.compactMap { parseNote($0) }
        guard !notes.isEmpty else {
            return .failure(.invalidNote(tokens.first ?? "?"))
        }
        
        let waveform = parseWaveform(from: tokens) ?? .sine
        let velocity = parseParam("vel", from: tokens).flatMap(Double.init) ?? 0.8
        
        for note in notes {
            engine.play(note, waveform: waveform, envelope: .pluck, velocity: velocity, duration: 1.5)
        }
        
        return .success(ParseInfo(description: "Playing \(notes.map(\.name).joined(separator: " "))"))
    }
    
    private func executeChord(tokens: [String]) -> Result<ParseInfo, DSLError> {
        guard !tokens.isEmpty else { return .failure(.missingArgument("chord")) }
 
        let notes = tokens.compactMap { parseNote($0) }
        guard !notes.isEmpty else {
            return .failure(.invalidNote(tokens.first ?? "?"))
        }
 
        let waveform = parseWaveform(from: tokens) ?? .sine
        let duration = parseParam("dur", from: tokens).flatMap(Double.init) ?? 2.0
        let velocity = parseParam("vel", from: tokens).flatMap(Double.init) ?? 0.75
 
        engine.chord(notes, waveform: waveform, envelope: .pad,
                     velocity: velocity, duration: duration)
 
        return .success(ParseInfo(
            description: "Chord: \(notes.map(\.name).joined(separator: " "))"
        ))
    }
 
    private func executeSequence(tokens: [String], ctx: LineContext) -> Result<ParseInfo, DSLError> {
        // Syntax: sequence [C4 (C4+E4+G4) - G4] bpm:120 wave:sine env:pluck
        //
        // Each step token is one of:
        //   C4          → single note
        //   (C4+E4+G4)  → chord (multiple notes playing simultaneously)
        //   -           → rest (silence)
        //
        // Collect the raw step tokens from inside the brackets.
        var stepTokens: [String] = []
        var inBrackets = false
        let current = ""

        for token in tokens {
            let t = token.hasPrefix("[") ? String(token.dropFirst()) : token
            let t2 = t.hasSuffix("]") ? String(t.dropLast()) : t

            if token.hasPrefix("[") { inBrackets = true }

            if inBrackets && !t2.isEmpty {
                stepTokens.append(t2)
            } else if !inBrackets && (parseNote(token) != nil || token == "-" || token.hasPrefix("(")) {
                stepTokens.append(token)
            }

            if token.hasSuffix("]") { inBrackets = false }
            _ = current
        }

        guard !stepTokens.isEmpty else {
            return .failure(.missingArgument("sequence"))
        }

        let bpm      = parseParam("bpm", from: tokens).flatMap(Double.init) ?? 120.0
        let waveform = parseWaveform(from: tokens) ?? .sine
        let envelope = parseEnvelope(from: tokens) ?? .pluck
        let timbre = parseTimbre(from: tokens)
        let duration = Duration.quarter

        // Build Step array — each token becomes a Step
        let steps: [Step] = stepTokens.map { token in
            if token == "-" {
                // Rest
                return Step(note: nil, duration: duration, waveform: waveform, envelope: envelope, timbre: timbre)
            } else if token.hasPrefix("(") && token.hasSuffix(")") {
                // Chord step: (C4+E4+G4) — extract notes, use first as Step note,
                // the rest fire as simultaneous noteOns via a special chord step.
                // For now we use the root note as the Step's note and store the
                // full chord in a ChordStep wrapper below.
                let inner = String(token.dropFirst().dropLast())
                let chordNotes = inner.components(separatedBy: "+").compactMap { parseNote($0.trimmingCharacters(in: .whitespaces)) }
                let root = chordNotes.first
                return Step(note: root, duration: duration,
                           velocity: 0.8, waveform: waveform, envelope: envelope, timbre: timbre,
                           chordNotes: chordNotes.count > 1 ? chordNotes : nil)
            } else {
                let note = parseNote(token)
                return Step(note: note, duration: duration, waveform: waveform, envelope: envelope, timbre: timbre)
            }
        }

        let sequence = Sequence(name: "\(steps.count) steps", steps: steps)
        engine.play(sequence, bpm: bpm)

        let noteRanges = computeNoteCharRanges(stepTokens: stepTokens, ctx: ctx)
        let seqInfo = SequenceLineInfo(
            lineIndex: ctx.lineIndex,
            lineCharRange: NSRange(location: ctx.utf16Offset, length: ctx.utf16Length),
            stepCount: steps.count,
            noteCharRanges: noteRanges
        )

        return .success(ParseInfo(
            description: "\(steps.count) steps @ \(Int(bpm)) BPM",
            stepCount: steps.count,
            sequences: [seqInfo]
        ))
    }
 
    private func executeReverb(tokens: [String]) -> Result<ParseInfo, DSLError> {
        let value = tokens.first.flatMap(Float.init) ?? 25.0
        engine.reverbMix = value.clamped(to: 0...100)
        return .success(ParseInfo(description: "Reverb \(Int(value))%"))
    }
 
    private func executeFilter(tokens: [String]) -> Result<ParseInfo, DSLError> {
        let value = tokens.first.flatMap(Double.init) ?? 8000.0
        engine.filterCutoff = value.clamped(to: 20...20000)
        return .success(ParseInfo(description: "Filter \(Int(value))Hz"))
    }
 
    private func executeDelay(tokens: [String]) -> Result<ParseInfo, DSLError> {
        let time = tokens.first.flatMap(Double.init) ?? 0.25
        let mix = parseParam("mix", from: tokens).flatMap(Double.init) ?? 0.3
        let feedback = parseParam("feedback", from: tokens).flatMap(Double.init) ?? 0.3
 
        engine.delayTime = time.clamped(to: 0...2)
        engine.delayMix = mix.clamped(to: 0...1)
        engine.delayFeedback = feedback.clamped(to: 0...0.95)
 
        return .success(ParseInfo(description: "Delay \(Int(time * 1000))ms"))
    }
 
    private func executeTempo(tokens: [String]) -> Result<ParseInfo, DSLError> {
        guard let bpm = tokens.first.flatMap(Double.init) else {
            return .failure(.missingArgument("tempo"))
        }
        
        engine.setTempo(bpm.clamped(to: 20...300))
        return .success(ParseInfo(description: "\(Int(bpm)) BPM"))
    }
 
    // MARK: - Step character ranges

    private func computeNoteCharRanges(stepTokens: [String], ctx: LineContext) -> [NSRange] {
        var searchOffset = ctx.utf16Offset
        let lineEnd = ctx.utf16Offset + ctx.utf16Length
        var ranges: [NSRange] = []

        for token in stepTokens {
            guard token != "-" else {
                ranges.append(NSRange(location: NSNotFound, length: 0))
                continue
            }
            let remaining = lineEnd - searchOffset
            guard remaining > 0 else {
                ranges.append(NSRange(location: NSNotFound, length: 0))
                continue
            }
            let searchRange = NSRange(location: searchOffset, length: remaining)
            let found = ctx.nsFullText.range(of: token, options: [], range: searchRange)
            if found.location != NSNotFound {
                ranges.append(found)
                searchOffset = found.location + found.length
            } else {
                ranges.append(NSRange(location: NSNotFound, length: 0))
            }
        }
        return ranges
    }

    // MARK: - Note parsing
    /// Parse a note string like "C4", "D#3", "Eb5" into a Note.
    func parseNote(_ token: String) -> Note? {
        // Strip any trailing punctuation that might sneak in
        let t = token.trimmingCharacters(in: .punctuationCharacters)
 
        // Must end in a digit (octave)
        guard let lastChar = t.last, lastChar.isNumber else { return nil }
 
        let octave = Int(String(lastChar))!
        let pitchStr = String(t.dropLast()).uppercased()
 
        let pitch: Pitch? = {
            switch pitchStr {
            case "C": return .C
            case "C#", "DB": return .Cs
            case "D": return .D
            case "D#", "EB": return .Ds
            case "E": return .E
            case "F": return .F
            case "F#", "GB": return .Fs
            case "G": return .G
            case "G#", "AB": return .Gs
            case "A": return .A
            case "A#", "BB": return .As
            case "B": return .B
            default: return nil
            }
        }()
 
        guard let p = pitch else { return nil }
        return Note(p, octave: octave)
    }
 
    // MARK: - Parameter helpers
    /// Tokenise a line — split on whitespace, handle "key:value" intact
    private func tokenise(_ line: String) -> [String] {
        line.components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
 
    /// Find "key:value" parameter in token list
    private func parseParam(_ key: String, from tokens: [String]) -> String? {
        let prefix = "\(key):"
        return tokens
            .first { $0.lowercased().hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }
 
    private func parseWaveform(from tokens: [String]) -> Waveform? {
        guard let raw = parseParam("wave", from: tokens) else { return nil }
        switch raw.lowercased() {
        case "sine": return .sine
        case "square": return .square
        case "saw", "sawtooth": return .sawtooth
        case "triangle", "tri": return .triangle
        default: return nil
        }
    }
 
    private func parseEnvelope(from tokens: [String]) -> Envelope? {
        if let inst = parseParam("instrument", from: tokens) ?? parseParam("inst", from: tokens) {
            return envelopeForInstrument(inst.lowercased())
        }
        
        guard let raw = parseParam("env", from: tokens) else { return nil }
        switch raw.lowercased() {
        case "pluck": return .pluck
        case "piano": return .piano
        case "pad": return .pad
        case "organ": return .organ
        case "vibraphone", "vibe": return .vibraphone
        case "marimba": return .marimba
        case "bell": return .bell
        case "flute": return .flute
        case "strings", "string": return .strings
        default: return nil
        }
    }
    
    private func envelopeForInstrument(_ name: String) -> Envelope {
        switch name {
        case "vibraphone", "vibe":      return .vibraphone
        case "marimba":                 return .marimba
        case "bell":                    return .bell
        case "flute":                   return .flute
        case "strings", "string":       return .strings
        case "piano":                   return .piano
        case "organ":                   return .organ
        case "pad":                     return .pad
        default:                        return .pluck
        }
    }
    
    func timbreForInstrument(_ name: String) -> TimbrePreset {
        switch name.lowercased() {
        case "vibraphone", "vibe":      return .vibraphone
        case "marimba":                 return .marimba
        case "bell":                    return .bell
        case "flute":                   return .flute
        case "strings", "string":       return .strings
        default:                        return .none
        }
    }
    
    private func parseTimbre(from tokens: [String]) -> TimbrePreset {
        if let inst = parseParam("instrument", from: tokens) ?? parseParam("inst", from: tokens) {
            return timbreForInstrument(inst)
        }
        return .none
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
 
private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
