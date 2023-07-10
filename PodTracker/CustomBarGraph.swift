//
//  CustomBarGraph.swift
//  PodTracker
//
//  Created by Igor Baglaenko on 2023-05-22.
//

import SwiftUI
import Charts


struct CustomBarGraph: View {
    @EnvironmentObject var podData: PodGlobalData
   
    var body: some View {
        VStack(alignment: HorizontalAlignment.trailing) {
            Text(podData.range)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Chart (content: {
                
                ForEach ( podData.barData ) { bar in
                    BarMark(
                        x: .value("Shape Entry",  bar.entry),
                        y: .value("Shape Steps",  bar.stepsPercent),
                        width: MarkDimension.ratio(0.9)
                    )
                    
                    .foregroundStyle(.green)
                    .annotation(position: .overlay, alignment: Alignment.center){
                        
                        Text(bar.steps)
                            .foregroundColor(.black)
                    }
                    BarMark(
                        x: .value("Shape Entry",  bar.entry),
                        y: .value("Shape Steps",  bar.alertsPercent),
                        width: MarkDimension.ratio(0.9)
                        
                    )
                    .foregroundStyle(.red)
                    .annotation(position: .overlay, alignment: Alignment.center){
                        Text(bar.alerts)
                            .foregroundColor(.black)
                    }
                    
                }
            }
            )
            .chartYScale(domain: -0.015...1.015)
            .chartYAxis {
                AxisMarks {
                    AxisTick()
                }
            }
            .gesture(DragGesture(minimumDistance: 3.0, coordinateSpace: .local)
                .onEnded { value in
                    print(value.translation)
                    switch(value.translation.width, value.translation.height) {
                    case (...0, -80...80):
                        podData.setStartIndex(dir: 1)
                        break;
                    case (0..., -80...80):
                        podData.setStartIndex(dir: -1)
                        break;
                    default:
                        break
                    }
                }
            )
        }
    }
}

struct CustomBarGraph_Previews: PreviewProvider {
    static var previews: some View {
        CustomBarGraph()
            .environmentObject(PodGlobalData())
    }
}
