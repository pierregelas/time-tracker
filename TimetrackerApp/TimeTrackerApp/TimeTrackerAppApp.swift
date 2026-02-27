//
//  TimeTrackerAppApp.swift
//  TimeTrackerApp
//
//  Created by Pierre on 2026-02-27.
//

import SwiftUI

@main
struct TimeTrackerAppApp: App {
    init() {
        _ = AppDatabase.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}