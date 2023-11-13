//
//  ContentView.swift
//  PodTracker
//
//  Created by Igor Baglaenko on 2023-05-22.
//

import SwiftUI
//var connectionStatus: String = "Scanning POD devices"
struct ContentView: View {
    @EnvironmentObject var podData: PodGlobalData
    
    var body: some View {
        
        if podData.showActivation {
            ActivationView()
        }
        else {
            PodTrackerView()
        }
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View { 
        ContentView()
            .environmentObject(PodGlobalData())
    }
}
