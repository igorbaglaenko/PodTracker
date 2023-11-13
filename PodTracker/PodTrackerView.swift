//
//  PodTrackerView.swift
//  PodTracker
//
//  Created by Igor Baglaenko on 2023-09-17.
//

import SwiftUI

struct PodTrackerView: View {
    @EnvironmentObject var podData: PodGlobalData
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(podData.connectionStatus)
                        .italic()
                    Spacer()
                    Text(podData.batteryStatus)
                        .font(.footnote)
                        .bold()
                }
                Gauge()
                let visibleWidth = UIScreen.main.bounds.size.width
                HStack(alignment: .center, spacing: visibleWidth/3.6) {
                    Text("")
                    Text("\(podData.backPosition)%")
                    Text("\(podData.frontPosition)%")
                }
                
                Text(podData.overloadMsg)
                    .foregroundColor(.red)
                    .frame(width: visibleWidth)
                HStack(alignment: .center, spacing: 0)  {
                    Text("\(podData.maxAllowedTitle)")
                        .bold()
                        .foregroundColor(.indigo)
                    Spacer()
                    Text(podData.maxAllowed)
                    
                }
                Text(podData.currentPeriod)
                    .bold()
                    .frame(width: visibleWidth)
                    .foregroundColor(.indigo)
                HStack(alignment: VerticalAlignment.lastTextBaseline) {
                    if !podData.bleData.completeMonitor {
                        Text (podData.periodStart)
                            .bold()
                        ProgressView( value: podData.periodComplete, total: podData.periodDuration)
                            .scaleEffect(x: 1, y: 3, anchor: .center)
                        Text(podData.periodEnd)
                            .bold()
                    }
                    else {
                        Text("Tracking stopped")
                            .bold()
                            .frame(width: visibleWidth)
                            .foregroundColor(.indigo)
                    }
                    
                }
                
                HStack {
                    Picker(selection: $podData.pickerID, label: Text("bla bla"), content: {
                        Text("Weekly").tag(1)
                        if !podData.bleData.completeMonitor {
                            Text("Daily").tag(2)
                        }
                    })
                    .onChange(of: podData.pickerID, perform: { (value) in podData.setBarType(lastPeriod: true)})
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    
                    .padding()
                    VStack (alignment: HorizontalAlignment.leading) {
                        HStack(alignment: VerticalAlignment.bottom) {
                            Text("Alerts: ")
                                .bold()
                            Text(podData.alertsNo)
                                .foregroundColor(.red)
                            
                        }
                        HStack {
                            Text("Steps: ")
                                .bold()
                            Text(podData.stepsNo)
                        }
                    }
                    
                }
                CustomBarGraph()
                    .padding(EdgeInsets())
                
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu ("Info") {
                        Text("ver. 1.0.1 Aug 13,2023")
                        Text("Firmware: \(podData.codeVersion)")
                        Text("POD id: \(podData.macAddress)")
                    }
                    Menu ("Action"){
                        Button(podData.muteAlarm) {
                            podData.changeMuteAlarm()
                        }
                        NavigationLink("Weight bearing protocol" ) {
                            BearingProtocolView()
                        }
                    }
                }
            }
            .alert("Incomatible Firmware", isPresented: $podData.terminateApp, actions: {
            }, message: {
                Text(podData.terminateMsg)
            })
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                if !podData.appActiveView {
                    podData.appActiveView = true
                    podData.bleData.startScan()
                }
                //print("Active")
            } else if newPhase == .inactive {
                if podData.appActiveView {
                    podData.appActiveView = false
                    podData.bleData.disconnectPod()
                }
                //print("Inactive")
//            } else if newPhase == .background {
//                print("Background")
            }
        }
        
    }
}

struct PodTrackerView_Previews: PreviewProvider {
    static var previews: some View {
        PodTrackerView()
            .environmentObject(PodGlobalData())
    }
}
