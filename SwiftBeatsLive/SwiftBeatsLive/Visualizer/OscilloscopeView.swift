//
//  OscilloscopeView.swift
//  SwiftBeatsLive
//
//  Created by Tyler Maxwell on 6/3/26.
//

import SwiftUI

struct OscilloscopeView: View {
    let samples: [Float]
    
    var body: some View {
        Canvas { context, size in
            guard samples.count > 1 else { return }
            
            // Draw background grid
            drawGrid(context: context, size: size)
            
            // Draw waveform
            var path = Path()
            let step = size.width / CGFloat(samples.count - 1)
            let midY = size.height / 2
            
            for (i, sample) in samples.enumerated() {
                let x = CGFloat(i) * step
                let y = midY - CGFloat(sample) * (size.height * 0.45)
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            context.stroke(path, with: .color(Color(red: 0.0, green: 1.0, blue: 0.4)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            
            // Center Line
            var centerLine = Path()
            centerLine.move(to: CGPoint(x: 0, y: midY))
            centerLine.addLine(to: CGPoint(x: size.width, y: midY))
            context.stroke(centerLine, with: .color(.green.opacity(0.15)), lineWidth: 0.5)
            
            // Label
            context.draw(
                Text("SCOPE")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.green.opacity(0.4)),
                at: CGPoint(x: 28, y: 12)
            )
        }
        .background(.black)
    }
    
    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let gridColor = Color.green.opacity(0.07)
        let cols = 8
        let rows = 4
        
        for i in 1..<cols {
            var line = Path()
            let x = size.width * CGFloat(i) / CGFloat(cols)
            
            line.move(to: CGPoint(x: x, y: 0))
            line.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(line, with: .color(gridColor), lineWidth: 0.5)
        }
        
        for i in 1..<rows {
            var line = Path()
            let y = size.height * CGFloat(i) / CGFloat(rows)
            
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(line, with: .color(gridColor), lineWidth: 0.5)
        }
    }
}
