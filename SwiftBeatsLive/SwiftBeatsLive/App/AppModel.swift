//
//  AppModel.swift
//  SwiftBeatsLive
//
//  Created by Tyler Maxwell on 6/3/26.
//

import SwiftUI
import SwiftBeats

enum RunStatus: Equatable {
    case idle
    case running(sequenceName: String)
    case error(message: String)
    
    var label: String {
        switch self {
        case .idle: return "Ready"
        case .running(let name): return "▶ \(name)"
        case .error: return "Error"
        }
    }
    
    var color: Color {
        switch self {
        case .idle: return .secondary
        case .running: return .green
        case .error: return .red
        }
    }
    
    var errorMessage: String? {
        if case .error(let msg) = self { return msg }
        return nil
    }
}

@Observable
final class AppModel {
    private(set) var engine: SwiftBeats?
    private(set) var isEngineReady = false
    
    var editorText: String = defaultCode
    var status: RunStatus = .idle
    var bpm: Double = 120
    var currentStep: Int = 0
    var totalSteps: Int = 0
    var sequenceLineInfos: [SequenceLineInfo] = []
    var sequencerSteps: [Int: Int] = [:]
    var errorLineIndex: Int? = nil
    
    var oscilloscopeSamples: [Float] = Array(repeating: 0, count: 512)
    var spectrumMagnitudes: [Float] = Array(repeating: 0, count: 64)
    
    private var audioTap: AudioTap?
    private var displayLink: DisplayLinkDriver?
    
    func start() async {
        do {
            let e = try SwiftBeats()
            engine = e
            
            // Install audio tap for visualizer
            let tap = AudioTap(engine: e.audio)
            audioTap = tap
            
            // Start display link for visualizer
            displayLink = DisplayLinkDriver { [weak self] in
                self?.refreshVisualiser()
            }
            
            isEngineReady = true
            print("SwiftBeats Live: Ready")
        } catch {
            status = .error(message: "Engine failed to start: \(error.localizedDescription)")
        }
    }
    
    func run() {
        guard let engine else {
            status = .error(message: "Engine not ready yet. Wait a moment and try again.")
            return
        }
        
        // Stop any current playback
        engine.stop()
        engine.allNotesOff()
        status = .idle

        // Reset effects so commented-out lines don't persist into the next run
        engine.filterCutoff = 20000
        engine.reverbMix    = 0
        engine.delayMix     = 0
        engine.delayTime    = 0.25
        engine.delayFeedback = 0.3
        
        engine.onStepChange = { [weak self] step, _ in
            self?.currentStep = step
        }
        engine.onSequencerStep = { [weak self] seqIdx, step, _ in
            self?.sequencerSteps[seqIdx] = step
        }
        
        // Parse and execute the editor text
        let parser = DSLParser(engine: engine)
        let result = parser.execute(editorText)
        
        switch result {
        case .success(let info):
            status = .running(sequenceName: info.description)
            totalSteps = info.stepCount
            sequenceLineInfos = info.sequences
        case .failure(let error):
            status = .error(message: error.localizedDescription)
            sequenceLineInfos = []
        }
        errorLineIndex = parser.lastErrorLineIndex
    }
    
    func stop() {
        engine?.stop()
        engine?.allNotesOff()
        status = .idle
        currentStep = 0
        sequenceLineInfos = []
        sequencerSteps = [:]
        errorLineIndex = nil
    }
    
    func clearEditor() {
        editorText = ""
    }
    
    private func refreshVisualiser() {
        guard let tap = audioTap else { return }
        
        oscilloscopeSamples = tap.oscilloscopeSnapshot(count: 512)
        spectrumMagnitudes = tap.spectrumSnapshot(binCount: 64)
    }
    
    static let defaultCode = """
    // Welcome to SwiftBeats Live!
    // Press Cmd+R to play. Cmd+/ to comment/uncomment lines.
    // Each line layers on top of the others.

    // Layer 1 — bass line
    sequence [C2 - C2 - G2 - G2 -]  bpm:120  wave:sawtooth  env:pluck

    // Layer 2 — melody with a chord step
    sequence [C4 E4 (C4+E4+G4) - A4 G4 E4 -]  bpm:120  wave:triangle  env:pluck

    // Layer 3 — pad chord
    chord C3 E3 G3  wave:sine

    // Effects (try uncommenting these)
    // reverb 20
    // filter 3000
    // delay 0.25  mix:0.3
    """
}
