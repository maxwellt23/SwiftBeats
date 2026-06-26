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

struct DSLReferenceView: View {
    @State private var isExpanded = false
 
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("DSL REFERENCE")
                        .font(.system(size: 9, design: .monospaced))
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
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(dslExamples, id: \.command) { example in
                        HStack(alignment: .top, spacing: 12) {
                            Text(example.command)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.blue)
                                .frame(width: 100, alignment: .leading)
                            Text(example.description)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(Color.black.opacity(0.8))
        .overlay(alignment: .top) { Divider().background(Color.green.opacity(0.2)) }
    }
 
    private let dslExamples: [(command: String, description: String)] = [
        ("play C4 E4 G4", "Play notes immediately"),
        ("sequence + sequence", "Multiple sequences layer on top of each other"),
        ("(C4+E4+G4) in sequence", "Chord step — notes joined by + inside parentheses"),
        ("Cmd+/", "Toggle comment on selected lines"),
        ("chord C4 E4 G4", "Play notes as chord  wave:sine dur:2"),
        ("sequence [C4 D4 E4]", "Loop a sequence  bpm:120  wave:triangle"),
        ("wave:sine/square/saw/triangle", "Oscillator waveform"),
        ("env:pluck/piano/pad/organ", "Basic envelope presets"),
        ("env:vibraphone/marimba/bell", "Mallet instrument envelopes"),
        ("env:flute/strings", "Wind and string envelopes"),
        ("inst:vibraphone", "Shorthand — sets envelope + harmonic partial"),
        ("inst:marimba/bell/flute/strings", "Other instrument shorthands"),
        ("reverb 25", "Reverb mix 0–100"),
        ("filter 2000", "Low-pass cutoff 20–20000 Hz"),
        ("delay 0.3", "Delay time  mix:0.3  feedback:0.3"),
        ("tempo 140", "Change BPM while playing"),
        ("stop", "Stop all playback"),
        ("// comment", "Lines starting with // are ignored"),
        ("- (in sequence)", "A dash = rest (silence)"),
    ]
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
