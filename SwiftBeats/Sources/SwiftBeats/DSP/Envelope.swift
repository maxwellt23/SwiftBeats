//
//  Envelope.swift
//  SwiftBeats
//
//  Created by Tyler Maxwell on 6/2/26.
//

import Foundation

private enum EnvelopeStage {
    case idle
    case attack
    case decay
    case sustain
    case release
}

public struct Envelope: Sendable {
    public var attack: Double
    public var decay: Double
    public var sustain: Double
    public var release: Double
    
    private var stage: EnvelopeStage = .idle
    private var currentLevel: Double = 0.0
    
    public init(
        attack: Double = 0.01,
        decay: Double = 0.1,
        sustain: Double = 0.7,
        release: Double = 0.3
    ) {
        self.attack = attack
        self.decay = decay
        self.sustain = sustain
        self.release = release
    }
    
    public static let pluck = Envelope(attack: 0.001, decay: 0.3, sustain: 0.0, release: 0.1)
    public static let pad = Envelope(attack: 0.3, decay: 0.2, sustain: 0.8, release: 0.5)
    public static let piano = Envelope(attack: 0.005, decay: 0.4, sustain: 0.3, release: 0.3)
    public static let organ = Envelope(attack: 0.01, decay: 0.0, sustain: 1.0, release: 0.01)
    public static let vibraphone = Envelope(attack: 0.015, decay: 1.8, sustain: 0.0, release: 0.4)
    public static let marimba = Envelope(attack: 0.005, decay: 0.5, sustain: 0.0, release: 0.1)
    public static let bell = Envelope(attack: 0.001, decay: 3.5, sustain: 0.0, release: 0.8)
    public static let flute = Envelope(attack: 0.08, decay: 0.05, sustain: 0.9, release: 0.2)
    public static let strings = Envelope(attack: 0.25, decay: 0.1, sustain: 0.9, release: 0.4)
    
    public mutating func noteOn() {
        stage = .attack
    }
    
    public mutating func noteOff() {
        guard stage != .idle else { return }
        stage = .release
    }
    
    public mutating func forceIdle() {
        stage = .idle
        currentLevel = 0.0
    }
    
    public var isIdle: Bool { stage == .idle }
    
    public mutating func nextSample(sampleRate: Double) -> Double {
        switch stage {
        case .idle:
            return 0.0
        case .attack:
            let increment = 1.0 / (attack * sampleRate)
            currentLevel += increment
            
            if currentLevel >= 1.0 {
                currentLevel = 1.0
                stage = .decay
            }
        case .decay:
            let decrement = (1.0 - sustain) / (decay * sampleRate + 1)
            currentLevel -= decrement
            
            if currentLevel <= sustain {
                currentLevel = sustain
                stage = sustain > 0 ? .sustain : .idle
            }
        case .sustain:
            currentLevel = sustain
        case .release:
            let decrement = currentLevel / (release * sampleRate + 1)
            currentLevel -= decrement
            
            if currentLevel <= 0.001 {
                currentLevel = 0.0
                stage = .idle
            }
        }
        
        return currentLevel
    }
}
