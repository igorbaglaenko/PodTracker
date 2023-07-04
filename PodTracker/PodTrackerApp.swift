//
//  PodTrackerApp.swift
//  PodTracker
//
//  Created by Igor Baglaenko on 2023-05-22.
//

import SwiftUI

@main
struct PodTrackerApp: App {
    @StateObject private var podData = PodGlobalData()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(podData)
        }
    }
}
