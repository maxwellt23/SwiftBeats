import Foundation

struct SongPreset: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let code: String
}

let songPresets: [SongPreset] = [
    SongPreset(name: "Demo", icon: "🎛️", code: AppModel.defaultCode),

    SongPreset(name: "Minecraft Theme", icon: "🧱", code:
        "// Wet Hands - C418\n" +
        "sequence [A3 C#4 A4 B4 C#5 B4 A4 E4 D4 F#4 C#5 E5 C#5 A4 - -] bpm:148 instrument:string\n" +
        "sequence [- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - G#5 - - - - - A5 - F#5 - - - - - E5 F#5 G#5 - - - - - B5 C#6 - F#5 - - -] bpm:148 instrument:vibraphone\n" +
        "reverb 0"
    ),

    SongPreset(name: "Twinkle Twinkle", icon: "⭐", code:
        "// Twinkle Twinkle Little Star\n" +
        "sequence [C4 C4 G4 G4 A4 A4 G4 - F4 F4 E4 E4 D4 D4 C4 -] bpm:100 wave:triangle env:pluck"
    ),

    SongPreset(name: "Für Elise", icon: "🎹", code:
        "// Für Elise — Beethoven\n" +
        "sequence [E5 D#5 E5 D#5 E5 B4 D5 C5 A4 - C4 E4 A4 B4 - E4 G#4 B4 C5 - E4 E5 D#5 E5 D#5 E5 B4 D5 C5 A4 -] bpm:120 wave:sine env:piano\n" +
        "reverb 15"
    ),

    SongPreset(name: "Ode to Joy", icon: "🎻", code:
        "// Ode to Joy — Beethoven\n" +
        "sequence [E4 E4 F4 G4 G4 F4 E4 D4 C4 C4 D4 E4 E4 D4 D4 -] bpm:108 wave:triangle env:piano\n" +
        "chord C3 G3 wave:sine"
    ),

    SongPreset(name: "Happy Birthday", icon: "🎂", code:
        "// Happy Birthday\n" +
        "sequence [G4 G4 A4 G4 C5 B4 - G4 G4 A4 G4 D5 C5 - G4 G4 G5 E5 C5 B4 A4 - F5 F5 E5 C5 D5 C5 -] bpm:90 wave:sine env:piano"
    ),

    SongPreset(name: "Smoke on the Water", icon: "🤘", code:
        "// Smoke on the Water — Deep Purple\n" +
        "sequence [G3 - Bb3 B3 - G3 - Bb3 C4 Bb3 G3 - - -] bpm:112 wave:sawtooth env:pluck\n" +
        "sequence [G2 - Bb2 B2 - G2 - Bb2 C3 Bb2 G2 - - -] bpm:112 wave:sawtooth env:pluck\n" +
        "reverb 10"
    ),

    SongPreset(name: "Mary Had a Lamb", icon: "🐑", code:
        "// Mary Had a Little Lamb\n" +
        "sequence [E4 D4 C4 D4 E4 E4 E4 - D4 D4 D4 - E4 G4 G4 - E4 D4 C4 D4 E4 E4 E4 E4 D4 D4 E4 D4 C4 -] bpm:110 wave:triangle env:pluck"
    ),

    SongPreset(name: "Music 4 Machines", icon: "🤖", code:
        "// Music 4 Machines — Grimes (cover by KAIXI)\n" +
        "\n" +
        "// Sub bass — punchy sawtooth, 8 measures × 4 quarter notes\n" +
        "sequence [C2 C2 C2 C2 G1 G1 G1 G1 Eb1 Eb1 Eb1 Eb1 Eb1 Eb1 F1 F1 C2 C2 C2 C2 G1 G1 Bb1 Bb1 Eb1 Eb1 Eb1 Eb1 F1 F1 F1 F1] bpm:135 inst:synthbass vol:0.9 decay:0.5 release:0.15\n" +
        "\n" +
        "// Synth arpeggio — triangle plucks, 8th notes\n" +
        "sequence [C3 C4 Eb5 C3 C4 D5 C3 Bb4 G2 G3 Bb4 G2 G3 A4 G2 G4 Eb2 Eb3 G4 Eb2 Eb3 F4 Eb2 G4 Eb2 Eb3 G4 Eb2 Eb3 F4 F2 G4 C3 C4 Eb5 C3 C4 D5 C3 Bb4 G2 G3 Bb4 G2 Bb4 C5 Bb2 G4 Eb2 Eb3 G4 Eb2 Eb3 F4 Eb2 G4 F2 F3 G4 F2 F3 A4 F2 A4] bpm:135 step:eighth inst:arp vol:0.6\n" +
        "\n" +
        "// Synth bass stabs — square wave, 8th notes\n" +
        "sequence [C3 C4 - C3 C4 - C3 - G2 G3 - G2 G3 - G2 - Eb2 Eb3 - Eb2 Eb3 - Eb2 - Eb2 Eb3 - Eb2 Eb3 - F2 - C3 C4 - C3 C4 - C3 - G2 G3 - G2 G3 - Bb2 - Eb2 Eb3 - Eb2 Eb3 - Eb2 - F2 F3 - F2 F3 - F2 -] bpm:135 step:eighth inst:lead vol:0.5 decay:0.15 sustain:0.3\n" +
        "\n" +
        "// Lead melody — flute, 8th notes\n" +
        "sequence [- - Eb5 - - D5 - Bb4 - - Bb4 - - A4 - G4 - - G4 - - F4 - G4 - - G4 - - F4 - G4 - - Eb5 - - D5 - Bb4 - - Bb4 - Bb4 C5 - G4 - - G4 - - F4 - G4 - - G4 - - A4 - A4] bpm:135 step:eighth inst:flute vol:0.7 attack:0.04 release:0.25\n" +
        "\n" +
        "reverb 30\n" +
        "delay 0.225 mix:0.25 feedback:0.4"
    ),
]
