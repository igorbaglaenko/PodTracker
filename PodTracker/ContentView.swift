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
                    Text (podData.periodStart)
                        .bold()
                    ProgressView( value: podData.periodComplete, total: podData.periodDuration)
                        .scaleEffect(x: 1, y: 3, anchor: .center)
                    Text(podData.periodEnd)
                        .bold()
                }
                
                HStack {
                    Picker(selection: $podData.pickerID, label: Text("bla bla"), content: {
                        Text("Weekly").tag(1)
                        Text("Daily").tag(2)
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
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View { 
        ContentView()
            .environmentObject(PodGlobalData())
    }
}
