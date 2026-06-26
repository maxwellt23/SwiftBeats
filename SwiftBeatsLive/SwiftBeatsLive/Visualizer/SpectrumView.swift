//
//  SpectrumView.swift
//  SwiftBeatsLive
//
//  Created by Tyler Maxwell on 6/3/26.
//

import SwiftUI

struct SpectrumView: View {
    let magnitudes: [Float]
 
    @State private var peaks: [Float] = Array(repeating: 0, count: 64)
    @State private var peakDecay: [Float] = Array(repeating: 0, count: 64)
 
    private let freqLabels: [(index: Int, label: String)] = [
        (0, "20"), (8, "100"), (20, "1k"), (40, "5k"), (63, "20k")
    ]
 
    var body: some View {
        Canvas { context, size in
            guard !magnitudes.isEmpty else { return }
 
            drawGrid(context: context, size: size)
 
            let count = magnitudes.count
            let barWidth = size.width / CGFloat(count)
            let gap: CGFloat = barWidth > 4 ? 1 : 0
 
            for i in 0..<count {
                let magnitude = CGFloat(magnitudes[i])
                let barHeight = magnitude * size.height
 
                let x = CGFloat(i) * barWidth
                let y = size.height - barHeight
 
                // Bar colour: green → yellow → red based on magnitude
                let colour = barColour(magnitude: magnitudes[i])
 
                var bar = Path()
                bar.addRect(CGRect(x: x + gap/2, y: y,
                                   width: max(barWidth - gap, 1), height: barHeight))
                context.fill(bar, with: .color(colour))
 
                // Peak indicator — a thin bright line at the peak hold position
                let peak = CGFloat(peaks[i])
                if peak > 0.02 {
                    var peakLine = Path()
                    let py = size.height - peak * size.height
                    peakLine.addRect(CGRect(x: x + gap/2, y: py,
                                           width: max(barWidth - gap, 1), height: 1.5))
                    context.fill(peakLine, with: .color(.white.opacity(0.6)))
                }
            }
 
            // Frequency labels
            for label in freqLabels {
                let x = CGFloat(label.index) * barWidth + barWidth / 2
                context.draw(
                    Text(label.label)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.4)),
                    at: CGPoint(x: x, y: size.height - 10)
                )
            }
 
            // Label
            context.draw(
                Text("SPECTRUM").font(.system(size: 9, design: .monospaced)).foregroundStyle(.green.opacity(0.4)),
                at: CGPoint(x: 36, y: 12)
            )
        }
        .background(Color.black)
        .onChange(of: magnitudes) { _, newMags in
            updatePeaks(newMags)
        }
    }
 
    private func updatePeaks(_ newMags: [Float]) {
        let decay: Float = 0.02
        for i in 0..<min(peaks.count, newMags.count) {
            if newMags[i] > peaks[i] {
                peaks[i] = newMags[i]
            } else {
                peaks[i] = max(0, peaks[i] - decay)
            }
        }
    }
 
    private func barColour(magnitude: Float) -> Color {
        switch magnitude {
        case 0..<0.5: return Color(red: 0.0, green: Double(magnitude * 2), blue: 0.2)
        case 0.5..<0.8: return Color(red: Double((magnitude - 0.5) * 3.3), green: 1.0, blue: 0.0)
        default: return Color(red: 1.0, green: Double(1.0 - (magnitude - 0.8) * 5), blue: 0.0)
        }
    }
 
    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let gridColor = Color.green.opacity(0.07)
        for i in 1..<4 {
            var line = Path()
            let y = size.height * CGFloat(i) / 4
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(line, with: .color(gridColor), lineWidth: 0.5)
        }
    }
}
