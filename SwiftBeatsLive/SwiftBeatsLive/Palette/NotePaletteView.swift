import SwiftUI

extension Notification.Name {
    static let insertNote = Notification.Name("SwiftBeatsInsertNote")
    static let appendLine = Notification.Name("SwiftBeatsAppendLine")
}

// MARK: - Palette tab

private enum PaletteTab: String, CaseIterable {
    case notes       = "Notes"
    case instruments = "Instruments"
    case effects     = "Effects"

    var icon: String {
        switch self {
        case .notes:       return "music.note"
        case .instruments: return "pianokeys"
        case .effects:     return "sparkles"
        }
    }
}

// MARK: - Main view

struct NotePaletteView: View {
    @State private var activeTab: PaletteTab = .notes
    @State private var isExpanded = false

    // Notes tab state
    @State private var rootIndex  = 0
    @State private var scaleIndex = 0
    @State private var octave     = 4

    private let roots = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
    private let scales: [(name: String, intervals: [Int])] = [
        ("Major",       [0, 2, 4, 5, 7, 9, 11]),
        ("Minor",       [0, 2, 3, 5, 7, 8, 10]),
        ("Pentatonic",  [0, 2, 4, 7, 9]),
        ("Blues",       [0, 3, 5, 6, 7, 10]),
        ("Dorian",      [0, 2, 3, 5, 7, 9, 10]),
        ("Mixolydian",  [0, 2, 4, 5, 7, 9, 10]),
    ]

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

            // ── Header ──────────────────────────────────────────────────
            HStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text("PALETTE")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.green.opacity(0.5))
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9))
                            .foregroundStyle(.green.opacity(0.4))
                    }
                    .padding(.leading, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Spacer()

                    // Tab bar
                    HStack(spacing: 0) {
                        ForEach(PaletteTab.allCases, id: \.self) { tab in
                            Button {
                                withAnimation(.easeInOut(duration: 0.12)) { activeTab = tab }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 9))
                                    Text(tab.rawValue)
                                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                }
                                .foregroundStyle(activeTab == tab ? .green : .white.opacity(0.35))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(activeTab == tab ? Color.green.opacity(0.12) : .clear)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.trailing, 4)
                } else {
                    Spacer()
                }
            }

            // ── Tab content ─────────────────────────────────────────────
            if isExpanded {
                Group {
                    switch activeTab {
                    case .notes:
                        NotesTabView(
                            roots: roots,
                            scales: scales,
                            rootIndex: $rootIndex,
                            scaleIndex: $scaleIndex,
                            octave: $octave,
                            currentNotes: currentNotes
                        )
                    case .instruments:
                        InstrumentsTabView()
                    case .effects:
                        EffectsTabView()
                    }
                }
                .transition(.opacity)
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

// MARK: - Notes tab

private struct NotesTabView: View {
    let roots: [String]
    let scales: [(name: String, intervals: [Int])]
    @Binding var rootIndex: Int
    @Binding var scaleIndex: Int
    @Binding var octave: Int
    let currentNotes: [String]

    var body: some View {
        VStack(spacing: 0) {
            // Controls row
            HStack(spacing: 8) {
                Picker("", selection: $rootIndex) {
                    ForEach(0..<roots.count, id: \.self) { i in Text(roots[i]).tag(i) }
                }
                .pickerStyle(.menu).labelsHidden().frame(width: 52)

                Picker("", selection: $scaleIndex) {
                    ForEach(0..<scales.count, id: \.self) { i in Text(scales[i].name).tag(i) }
                }
                .pickerStyle(.menu).labelsHidden().frame(width: 95)

                HStack(spacing: 2) {
                    Button { if octave > 1 { octave -= 1 } } label: {
                        Image(systemName: "minus").font(.system(size: 9, weight: .semibold)).frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)

                    Text("Oct \(octave)–\(octave + 1)")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).frame(width: 56)

                    Button { if octave < 5 { octave += 1 } } label: {
                        Image(systemName: "plus").font(.system(size: 9, weight: .semibold)).frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)

            // Note chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(Array(currentNotes.enumerated()), id: \.offset) { idx, note in
                        if idx == scales[scaleIndex].intervals.count {
                            Divider().frame(height: 20).padding(.horizontal, 2)
                        }
                        PaletteChip(label: note, color: .green) {
                            NotificationCenter.default.post(name: .insertNote, object: note + " ")
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Instruments tab

private struct InstrumentsTabView: View {
    private let synths: [(label: String, insert: String)] = [
        ("synthbass", "inst:synthbass"),
        ("lead",      "inst:lead"),
        ("arp",       "inst:arp"),
        ("ambientpad","inst:ambientpad"),
        ("plucked",   "inst:plucked"),
    ]
    private let acoustic: [(label: String, insert: String)] = [
        ("bell",      "inst:bell"),
        ("vibraphone","inst:vibraphone"),
        ("marimba",   "inst:marimba"),
        ("flute",     "inst:flute"),
        ("strings",   "inst:strings"),
        ("piano",     "inst:piano"),
        ("organ",     "inst:organ"),
        ("pad",       "inst:pad"),
        ("pluck",     "inst:pluck"),
    ]
    private let waves: [(label: String, insert: String)] = [
        ("sine",     "wave:sine"),
        ("square",   "wave:square"),
        ("sawtooth", "wave:sawtooth"),
        ("triangle", "wave:triangle"),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ChipGroup(title: "SYNTH", chips: synths, color: .cyan)
                Divider().frame(height: 40)
                ChipGroup(title: "ACOUSTIC", chips: acoustic, color: .teal)
                Divider().frame(height: 40)
                ChipGroup(title: "WAVEFORM", chips: waves, color: .orange)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Effects tab

private struct EffectsTabView: View {
    private let reverbs: [(label: String, value: String)] = [
        ("Off",  "reverb 0"),
        ("10%",  "reverb 10"),
        ("25%",  "reverb 25"),
        ("50%",  "reverb 50"),
        ("80%",  "reverb 80"),
    ]
    private let delays: [(label: String, value: String)] = [
        ("Off",      "delay 0 mix:0"),
        ("Short",    "delay 0.125 mix:0.25 feedback:0.3"),
        ("Medium",   "delay 0.25 mix:0.3 feedback:0.4"),
        ("Long",     "delay 0.375 mix:0.35 feedback:0.5"),
        ("Slapback", "delay 0.06 mix:0.4 feedback:0.1"),
    ]
    private let filters: [(label: String, value: String)] = [
        ("Open",    "filter 20000"),
        ("Bright",  "filter 8000"),
        ("Mid",     "filter 3000"),
        ("Warm",    "filter 1200"),
        ("Dark",    "filter 500"),
    ]
    private let stepDurations: [(label: String, insert: String)] = [
        ("sixteenth", "step:sixteenth"),
        ("eighth",    "step:eighth"),
        ("quarter",   "step:quarter"),
        ("half",      "step:half"),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ChipGroup(title: "REVERB", chips: reverbs.map { ($0.label, $0.value) }, color: .purple, asLine: true)
                Divider().frame(height: 40)
                ChipGroup(title: "DELAY", chips: delays.map { ($0.label, $0.value) }, color: .indigo, asLine: true)
                Divider().frame(height: 40)
                ChipGroup(title: "FILTER", chips: filters.map { ($0.label, $0.value) }, color: .orange, asLine: true)
                Divider().frame(height: 40)
                ChipGroup(title: "STEP SIZE", chips: stepDurations, color: .teal, asLine: false)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Shared chip components

private struct ChipGroup: View {
    let title: String
    let chips: [(label: String, insert: String)]
    let color: Color
    var asLine: Bool = false    // true → posts appendLine, false → insertNote

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(color.opacity(0.6))

            HStack(spacing: 4) {
                ForEach(chips, id: \.label) { chip in
                    PaletteChip(label: chip.label, color: color) {
                        let text = asLine ? chip.insert + "\n" : chip.insert + " "
                        let notif: Notification.Name = asLine ? .appendLine : .insertNote
                        NotificationCenter.default.post(name: notif, object: text)
                    }
                }
            }
        }
    }
}

struct PaletteChip: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(color.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help("Insert \(label)")
    }
}
