//
//  ContentView.swift
//  SwiftBeatsLive
//
//  Created by Tyler Maxwell on 6/3/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var splitPosition: CGFloat = 420
    
    var body: some View {
        @Bindable var model = model
        
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left panel: code editor + note palette
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        Color(red: 0.08, green: 0.08, blue: 0.10)

                        HStack(spacing: 0) {
                            LineNumberGutter(text: model.editorText)
                                .frame(width: 36)

                            CodeEditorView(
                                text: $model.editorText,
                                onRun: { model.run() },
                                sequenceLineInfos: model.sequenceLineInfos,
                                sequencerSteps: model.sequencerSteps,
                                errorLineIndex: model.errorLineIndex
                            )
                        }
                    }
                    .frame(maxHeight: .infinity)

                    NotePaletteView()
                }
                .frame(width: splitPosition)
                .overlay(alignment: .trailing) {
                    DividerHandle(position: $splitPosition)
                }

                // Right panel: visualiser
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("SwiftBeats Live")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.green.opacity(0.8))

                        Spacer()

                        if case .running = model.status, model.totalSteps > 0 {
                            Text("Step \(model.currentStep + 1) of \(model.totalSteps)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.green.opacity(0.5))
                        }

                        Menu {
                            ForEach(songPresets) { preset in
                                Button("\(preset.icon)  \(preset.name)") {
                                    model.editorText = preset.code
                                    model.run()
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "music.note.list")
                                Text("Presets")
                            }
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.green.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black)
                    
                    // Visualizer panels
                    VisualizerView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // DSL Reference Card
                    DSLReferenceView()
                }
                .frame(maxWidth: .infinity)
                .background(.black)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Transport bar
            TransportView()
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.10))
        .preferredColorScheme(.dark)
    }
}

struct DividerHandle: View {
    @Binding var position: CGFloat
    @State private var isDragging = false
 
    var body: some View {
        Rectangle()
            .fill(isDragging ? Color.green.opacity(0.5) : Color.gray.opacity(0.2))
            .frame(width: 4)
            .cursor(.resizeLeftRight)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        position = max(280, min(1000, position + value.translation.width))
                    }
                    .onEnded { _ in isDragging = false }
            )
    }
}

// MARK: - DSL Reference

private struct RefItem: Identifiable {
    let id = UUID()
    let keyword: String
    let detail: String
    let keywordColor: Color
}

private struct RefSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [RefItem]
}

struct DSLReferenceView: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text("DSL REFERENCE")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.5))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.green.opacity(0.4))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(section.title)
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.3))
                                    .padding(.bottom, 2)

                                ForEach(section.items) { item in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text(item.keyword)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(item.keywordColor)
                                            .frame(width: 168, alignment: .leading)
                                        Text(item.detail)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white.opacity(0.45))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .frame(maxHeight: 300)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(Color.black.opacity(0.8))
        .overlay(alignment: .top) { Divider().background(Color.green.opacity(0.2)) }
    }

    private var sections: [RefSection] {[
        RefSection(title: "COMMANDS", items: [
            RefItem(keyword: "sequence [C4 D4 E4 -]",  detail: "Loop a note pattern. - is a rest, (C4+E4) is a chord step.", keywordColor: .blue),
            RefItem(keyword: "play C4 E4",              detail: "Play one or more notes immediately.", keywordColor: .blue),
            RefItem(keyword: "chord C4 E4 G4",          detail: "Strike notes as a held chord.", keywordColor: .blue),
            RefItem(keyword: "reverb 25",               detail: "Global reverb mix 0–100.", keywordColor: .blue),
            RefItem(keyword: "filter 2000",             detail: "Low-pass filter cutoff 20–20000 Hz.", keywordColor: .blue),
            RefItem(keyword: "delay 0.25 mix:0.3",      detail: "Echo delay time in seconds. Optional: feedback:0.4", keywordColor: .blue),
            RefItem(keyword: "tempo 140",               detail: "Set global BPM while playing.", keywordColor: .blue),
            RefItem(keyword: "stop",                    detail: "Stop all playback.", keywordColor: .blue),
        ]),
        RefSection(title: "SEQUENCE PARAMETERS", items: [
            RefItem(keyword: "bpm:135",                 detail: "Playback speed for this sequence.", keywordColor: .orange),
            RefItem(keyword: "step:eighth",             detail: "Note duration: sixteenth / eighth / quarter / half / whole", keywordColor: .orange),
            RefItem(keyword: "vol:0.8",                 detail: "Per-sequence gain 0.0–1.0.", keywordColor: .orange),
            RefItem(keyword: "oct:+1  oct:-1",          detail: "Shift all notes up or down by octaves.", keywordColor: .orange),
            RefItem(keyword: "wave:sine",               detail: "Oscillator waveform (see Waveforms below).", keywordColor: .orange),
            RefItem(keyword: "inst:lead",               detail: "Instrument preset — sets waveform + envelope (see Instruments).", keywordColor: .orange),
            RefItem(keyword: "env:pluck",               detail: "Envelope preset override (see Instruments).", keywordColor: .orange),
            RefItem(keyword: "attack:0.01",             detail: "ADSR attack time in seconds (overrides env: preset).", keywordColor: .orange),
            RefItem(keyword: "decay:0.3",               detail: "ADSR decay time in seconds.", keywordColor: .orange),
            RefItem(keyword: "sustain:0.5",             detail: "ADSR sustain level 0.0–1.0.", keywordColor: .orange),
            RefItem(keyword: "release:0.2",             detail: "ADSR release time in seconds.", keywordColor: .orange),
        ]),
        RefSection(title: "WAVEFORMS", items: [
            RefItem(keyword: "sine",                    detail: "Pure, smooth tone.", keywordColor: Color.teal),
            RefItem(keyword: "square",                  detail: "Hollow, buzzy — classic synth.", keywordColor: Color.teal),
            RefItem(keyword: "sawtooth  saw",           detail: "Bright, harsh — good for bass.", keywordColor: Color.teal),
            RefItem(keyword: "triangle  tri",           detail: "Soft, round — between sine and square.", keywordColor: Color.teal),
        ]),
        RefSection(title: "INSTRUMENTS  (inst: or env:)", items: [
            RefItem(keyword: "synthbass",               detail: "Punchy sawtooth bass.", keywordColor: Color.teal),
            RefItem(keyword: "lead",                    detail: "Square-wave synth lead.", keywordColor: Color.teal),
            RefItem(keyword: "arp",                     detail: "Quick triangle mallet — good for arpeggios.", keywordColor: Color.teal),
            RefItem(keyword: "ambientpad  ambient",     detail: "Slow-attack sine pad.", keywordColor: Color.teal),
            RefItem(keyword: "plucked  harp",           detail: "Triangle with bell harmonic.", keywordColor: Color.teal),
            RefItem(keyword: "bell",                    detail: "Long-ringing metallic tone.", keywordColor: Color.teal),
            RefItem(keyword: "vibraphone  vibe",        detail: "Metallic shimmer partial.", keywordColor: Color.teal),
            RefItem(keyword: "marimba",                 detail: "Wooden bar, soft partial.", keywordColor: Color.teal),
            RefItem(keyword: "flute",                   detail: "Breathy with octave partial.", keywordColor: Color.teal),
            RefItem(keyword: "strings  string",         detail: "Warm fifth-interval partial.", keywordColor: Color.teal),
            RefItem(keyword: "piano",                   detail: "Fast attack, gradual decay.", keywordColor: Color.teal),
            RefItem(keyword: "pad",                     detail: "Slow attack, long sustain.", keywordColor: Color.teal),
            RefItem(keyword: "organ",                   detail: "Instant attack, full sustain.", keywordColor: Color.teal),
            RefItem(keyword: "pluck",                   detail: "Snap attack, no sustain.", keywordColor: Color.teal),
        ]),
        RefSection(title: "TIPS", items: [
            RefItem(keyword: "//  comment",             detail: "Lines starting with // are ignored.", keywordColor: .gray),
            RefItem(keyword: "-  (in sequence)",        detail: "Dash = rest (silence for one step).", keywordColor: .gray),
            RefItem(keyword: "(C4+E4+G4)",              detail: "Chord step inside a sequence — notes joined by +.", keywordColor: .gray),
            RefItem(keyword: "Cmd+Enter",               detail: "Run the code.", keywordColor: .gray),
            RefItem(keyword: "Cmd+/",                   detail: "Toggle comment on selected lines.", keywordColor: .gray),

            RefItem(keyword: "Multiple sequence lines", detail: "Each sequence plays simultaneously as a separate layer.", keywordColor: .gray),
        ]),
    ]}
}

private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
