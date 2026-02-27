//
//  TimeTrackerAppApp.swift
//  TimeTrackerApp
//
//  Created by Pierre on 2026-02-27.
//

import AppKit
import SwiftUI

@main
struct TimeTrackerAppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var timerService = TimerService()

    init() {
        _ = AppDatabase.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(timerService)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    try? timerService.stop()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                try? timerService.stop()
            }
        }
    }
}
