//
//  VisualizerView.swift
//  SwiftBeatsLive
//
//  Created by Tyler Maxwell on 6/3/26.
//

import SwiftUI

struct VisualizerView: View {
    @Environment(AppModel.self) private var model
    
    var body: some View {
        VStack(spacing: 2) {
            OscilloscopeView(samples: model.oscilloscopeSamples)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
                .background(.green.opacity(0.3))
            
            SpectrumView(magnitudes: model.spectrumMagnitudes)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.black)
        .clipShape(.rect(cornerRadius: 8))
    }
}
