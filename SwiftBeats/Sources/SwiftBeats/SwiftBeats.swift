import Foundation

@MainActor
public final class SwiftBeats {
    public let audio: AudioEngine
    private var sequencers: [Sequencer] = []
    
    public var isRunning: Bool { audio.isRunning }
    
    public var filterCutoff: Double {
        get { audio.filterCutoff }
        set { audio.filterCutoff = newValue }
    }
    
    public var reverbMix: Float {
        get { audio.reverbMix }
        set { audio.reverbMix = newValue }
    }
    
    public var delayMix: Double {
        get { audio.delayMix }
        set { audio.delayMix = newValue }
    }
    
    public var delayFeedback: Double {
        get { audio.delayFeedback }
        set { audio.delayFeedback = newValue }
    }
    
    public var delayTime: Double {
        get { audio.delayTime }
        set { audio.delayTime = newValue }
    }
    
    public var activeVoiceCount: Int { audio.activeVoiceCount }
    public var activeNotes: [Note] { audio.activeNotes }
    
    public var isPlaying: Bool { sequencers.first?.isPlaying ?? false }
    public var currentStep: Int { sequencers.first?.currentStep ?? 0 }
    public var onStepChange: ((Int, Step) -> Void)?
    /// Fires for every sequencer on every step: (sequencerIndex, stepIndex, Step)
    public var onSequencerStep: ((Int, Int, Step) -> Void)?
    
    public init() throws {
        audio = AudioEngine()
        try audio.start()
    }
    
    public func noteOn(
        _ note: Note,
        waveform: Waveform = .sine,
        envelope: Envelope = .piano,
        velocity: Double = 0.8
    ) {
        audio.noteOn(note: note, waveform: waveform, envelope: envelope, velocity: velocity)
    }
    
    public func noteOff(_ note: Note) {
        audio.noteOff(note: note)
    }
    
    public func play(
        _ note: Note,
        waveform: Waveform = .sine,
        envelope: Envelope = .piano,
        velocity: Double = 0.8,
        duration: TimeInterval = 0.5
    ) {
        audio.scheduleNote(note: note, waveform: waveform, envelope: envelope,
                           velocity: velocity, duration: duration)
    }
    
    public func chord(
        _ notes: [Note],
        waveform: Waveform = .sine,
        envelope: Envelope = .pad,
        velocity: Double = 0.7,
        duration: TimeInterval? = nil
    ) {
        audio.chord(notes: notes, waveform: waveform, envelope: envelope,
                    velocity: velocity, duration: duration)
    }
    
    public func allNotesOff() {
        audio.allNotesOff()
    }
    
    public func play(_ sequence: Sequence, bpm: Double = 120) {
        let seq = Sequencer(engine: audio, bpm: bpm)
        let idx = sequencers.count

        seq.onStepChange = { [weak self] step, s in
            guard let self else { return }
            if idx == 0 { self.onStepChange?(step, s) }
            self.onSequencerStep?(idx, step, s)
        }

        sequencers.append(seq)
        seq.play(sequence)
    }
    
    public func stop() {
        sequencers.forEach { $0.stop() }
        sequencers.removeAll()
        audio.allNotesOff()
    }
    
    public func pause() {
        sequencers.forEach { $0.pause() }
    }
    
    public func resume() {
        sequencers.forEach { $0.resume() }
    }
    
    public func setTempo(_ bpm: Double) {
        sequencers.forEach { $0.bpm = bpm }
    }
    
    public static func majorChord(root: Note) -> [Note] {
        [root,
         Note(Pitch(rawValue: (root.pitch.rawValue + 4) % 12)!, octave: root.octave),
         Note(Pitch(rawValue: (root.pitch.rawValue + 7) % 12)!, octave: root.octave)]
    }
    
    public static func minorChord(root: Note) -> [Note] {
        [root,
         Note(Pitch(rawValue: (root.pitch.rawValue + 3) % 12)!, octave: root.octave),
         Note(Pitch(rawValue: (root.pitch.rawValue + 7) % 12)!, octave: root.octave)]
    }
}
