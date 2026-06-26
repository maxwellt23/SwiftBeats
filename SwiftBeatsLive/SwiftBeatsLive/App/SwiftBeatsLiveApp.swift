//
//  SwiftBeatsLiveApp.swift
//  SwiftBeatsLive
//
//  Created by Tyler Maxwell on 6/3/26.
//

import SwiftUI

@main
struct SwiftBeatsLiveApp: App {
    @State private var appModel = AppModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .task { await appModel.start() }
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Transport") {
                Button("Run Code") { appModel.run() }
                    .keyboardShortcut("r", modifiers: .command)
                
                Button("Stop") { appModel.stop() }
                    .keyboardShortcut(".", modifiers: .command)
                
                Divider()
                
                Button("Clear Editor") { appModel.clearEditor() }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }
    }
}
