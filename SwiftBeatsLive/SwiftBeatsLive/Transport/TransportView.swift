//
//  TransportView.swift
//  SwiftBeatsLive
//
//  Created by Tyler Maxwell on 6/3/26.
//


import SwiftUI
import SwiftBeats

struct TransportView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        HStack(spacing: 16) {

            // Run button
            Button {
                model.run()
            } label: {
                Label("Run", systemImage: "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("r", modifiers: .command)
            .help("Run code (⌘R)")

            // Stop button
            Button {
                model.stop()
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.red.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(".", modifiers: .command)
            .help("Stop (⌘.)")

            Divider().frame(height: 24)

            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(model.status.color)
                    .frame(width: 8, height: 8)
                    .shadow(color: model.status.color, radius: 3)

                Text(model.status.label)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(model.status.color)
                    .lineLimit(1)
                    .frame(maxWidth: 200, alignment: .leading)
            }

            // Error message if any
            if let error = model.status.errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 11))
                    Text(error)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .lineLimit(2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

