//
//  Filter.swift
//  SwiftBeats
//
//  Created by Tyler Maxwell on 6/2/26.
//

import Foundation

public struct OnePoleFilter {
    public var cutoff: Double {
        didSet { updateCoefficient() }
    }

    public var resonance: Double = 0.0

    private var coefficient: Double = 1.0  // 'a' in the formula above
    private var previousOutput: Double = 0.0
    private let sampleRate: Double

    public init(cutoff: Double = 8000.0, sampleRate: Double = 44100.0) {
        self.sampleRate = sampleRate
        self.cutoff = cutoff
        
        updateCoefficient()
    }

    public mutating func process(_ input: Double) -> Double {
        let output = coefficient * input + (1.0 - coefficient) * previousOutput
        previousOutput = output
        
        return output
    }

    public mutating func reset() {
        previousOutput = 0.0
    }

    private mutating func updateCoefficient() {
        let clampedCutoff = cutoff.clamped(to: 20.0...20000.0)
        let rc = 1.0 / (2.0 * .pi * clampedCutoff)
        let dt = 1.0 / sampleRate
        
        coefficient = dt / (rc + dt)
    }
}

public struct FourPoleFilter {
    private var stage1: OnePoleFilter
    private var stage2: OnePoleFilter
    private var stage3: OnePoleFilter
    private var stage4: OnePoleFilter

    public var cutoff: Double {
        didSet {
            stage1.cutoff = cutoff
            stage2.cutoff = cutoff
            stage3.cutoff = cutoff
            stage4.cutoff = cutoff
        }
    }

    public init(cutoff: Double = 8000.0, sampleRate: Double = 44100.0) {
        self.cutoff = cutoff
        stage1 = OnePoleFilter(cutoff: cutoff, sampleRate: sampleRate)
        stage2 = OnePoleFilter(cutoff: cutoff, sampleRate: sampleRate)
        stage3 = OnePoleFilter(cutoff: cutoff, sampleRate: sampleRate)
        stage4 = OnePoleFilter(cutoff: cutoff, sampleRate: sampleRate)
    }

    public mutating func process(_ input: Double) -> Double {
        stage4.process(stage3.process(stage2.process(stage1.process(input))))
    }

    public mutating func reset() {
        stage1.reset(); stage2.reset(); stage3.reset(); stage4.reset()
    }
}
