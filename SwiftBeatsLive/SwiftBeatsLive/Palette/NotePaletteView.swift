import SwiftUI

extension Notification.Name {
    static let insertNote = Notification.Name("SwiftBeatsInsertNote")
}

struct NotePaletteView: View {
    @State private var rootIndex  = 0   // C
    @State private var scaleIndex = 0   // Major
    @State private var octave     = 4
    @State private var isExpanded = false

    private let roots = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]

    private let scales: [(name: String, intervals: [Int])] = [
        ("Major",       [0, 2, 4, 5, 7, 9, 11]),
        ("Minor",       [0, 2, 3, 5, 7, 8, 10]),
        ("Pentatonic",  [0, 2, 4, 7, 9]),
        ("Blues",       [0, 3, 5, 6, 7, 10]),
        ("Dorian",      [0, 2, 3, 5, 7, 9, 10]),
        ("Mixolydian",  [0, 2, 4, 5, 7, 9, 10]),
    ]

    // Notes across two octaves, with correct octave numbers for wrapping roots (e.g. A Major: A4 B4 C#5…)
    private var currentNotes: [String] {
        let rootAbs = octave * 12 + rootIndex
        var notes: [String] = []
        for octOffset in [0, 1] {
            for interval in scales[scaleIndex].intervals {
                let abs     = rootAbs + octOffset * 12 + interval
                let noteIdx = abs % 12
                let noteOct = abs / 12
                notes.append("\(roots[noteIdx])\(noteOct)")
            }
        }
        return notes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header row ──────────────────────────────────────────────
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Text("NOTE PALETTE")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.5))

                    if isExpanded {
                        // Root picker
                        Picker("", selection: $rootIndex) {
                            ForEach(0..<roots.count, id: \.self) { i in
                                Text(roots[i]).tag(i)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 52)

                        // Scale picker
                        Picker("", selection: $scaleIndex) {
                            ForEach(0..<scales.count, id: \.self) { i in
                                Text(scales[i].name).tag(i)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 95)

                        // Octave stepper
                        HStack(spacing: 2) {
                            Button { if octave > 1 { octave -= 1 } } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 9, weight: .semibold))
                                    .frame(width: 18, height: 18)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)

                            Text("Oct \(octave)–\(octave + 1)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 56)

                            Button { if octave < 5 { octave += 1 } } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 9, weight: .semibold))
                                    .frame(width: 18, height: 18)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.green.opacity(0.4))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            // ── Note buttons ─────────────────────────────────────────────
            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(Array(currentNotes.enumerated()), id: \.offset) { idx, note in
                            // Dim separator between the two octaves
                            if idx == scales[scaleIndex].intervals.count {
                                Divider()
                                    .frame(height: 20)
                                    .padding(.horizontal, 2)
                            }
                            NoteChipButton(note: note)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(Color.black.opacity(0.85))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.green.opacity(0.15))
                .frame(height: 1)
        }
    }
}

private struct NoteChipButton: View {
    let note: String

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .insertNote, object: note + " ")
        } label: {
            Text(note)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help("Insert \(note)")
    }
}
