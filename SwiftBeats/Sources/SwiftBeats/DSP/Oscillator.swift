//
//  Oscillator.swift
//  SwiftBeats
//
//  Created by Tyler Maxwell on 6/2/26.
//

import Foundation

public struct Oscillator: Sendable {
    public var frequency: Double
    public var waveform: Waveform
    public var amplitude: Double
    
    private var phase: Double = 0.0
    
    public init(
        frequency: Double = 440.0,
        waveform: Waveform = .sine,
        amplitude: Double = 0.8
    ) {
        self.frequency = frequency
        self.waveform = waveform
        self.amplitude = amplitude.clamped(to: 0.0...1.0)
    }
    
    public init(
        note: Note,
        waveform: Waveform = .sine,
        amplitude: Double = 0.8
    ) {
        self.init(
            frequency: note.frequency,
            waveform: waveform,
            amplitude: amplitude
        )
    }
    
    public mutating func nextSample(sampleRate: Double) -> Double {
        let sample = waveformSample(phase: phase)
        
        phase += frequency / sampleRate
        if phase >= 1.0 { phase -= 1.0 }
        
        return sample * amplitude
    }
    
    public mutating func render(into buffer: inout [Float], sampleRate: Double) {
        let phaseIncrement = frequency / sampleRate
        
        for i in buffer.indices {
            buffer[i] = Float(waveformSample(phase: phase) * amplitude)
            
            phase += phaseIncrement
            if phase >= 1.0 { phase -= 1.0 }
        }
    }
    
    private func waveformSample(phase: Double) -> Double {
        switch waveform {
        case .sine:
            return sin(2.0 * .pi * phase)
        case .square:
            return phase < 0.5 ? 1.0 : -1.0
        case .sawtooth:
            return 2.0 * phase - 1.0
        case .triangle:
            if phase < 0.5 {
                return 4.0 * phase - 1.0
            } else {
                return 3.0 - 4.0 * phase
            }
        }
    }
    
    public mutating func reset() {
        phase = 0.0
    }
    
    public mutating func tune(to note: Note) {
        frequency = note.frequency
    }
}
