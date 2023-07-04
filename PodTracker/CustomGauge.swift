//
//  CustomGauge.swift
//  PodTracker
//
//  Created by Igor Baglaenko on 2023-05-22.
//

import SwiftUI



struct CustomGauge_Previews: PreviewProvider {
    static var previews: some View {
        Gauge()
            .environmentObject(PodGlobalData())
    }
    
}
struct GaugeShape: Shape {
    var clockwise: Bool
    var percent: Double
    var alarm: Bool
    func path(in rect: CGRect) -> Path {
   
        var path = Path()
        var center: CGPoint
        var startDegree: Angle
        var endDegree: Angle
        
        let allowedDegree = 0.9 * percent
        if  clockwise {
            center = CGPoint(x: rect.maxX, y: rect.maxY)
            if alarm {
                startDegree = .degrees(180)
                endDegree = .degrees(180 + allowedDegree)
            } else {
                startDegree = .degrees(180 + allowedDegree)
                endDegree = .degrees(270)
            }
        }
        else {
            center = CGPoint(x: rect.minX, y: rect.maxY)
            if alarm {
                startDegree = .degrees(0)
                endDegree = .degrees(-allowedDegree)

            } else {
                startDegree = .degrees(-allowedDegree)
                endDegree = .degrees(-90)
                
               
            }
        }
        
        path.addArc(
            center: center,
            radius: rect.height - 20,
            startAngle: startDegree,
            endAngle: endDegree,
            clockwise: !clockwise
        )
                                 
        return path
    }
}

struct GaugeKnob: Shape {
    var clockwise: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let radius = rect.height/35
        let origin: CGRect
        if clockwise {
            origin = CGRect(x: rect.maxX-radius, y: rect.maxY-radius, width: CGFloat(radius*2), height: CGFloat(radius*2))
        } else {
            origin = CGRect(x: rect.minX-radius, y: rect.maxY-radius, width: CGFloat(radius*2), height: CGFloat(radius*2))
        }
        path.addEllipse(in: origin)
        
        return path
    }
}

struct GaugeArrow: Shape {
    var clockwise: Bool
    var percent: Int

    var animatableData: Int {
        get { percent }
        set { percent = newValue}
    }
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = rect.height/35

        let arrowStart = CGPoint(x: rect.minX, y: rect.minY - radius)
        let arrowStop  = CGPoint(x: rect.minX, y: rect.minY + radius)
        let arrowTip = CGPoint(x: rect.maxX - 25, y: rect.minY)
      
        var arrowPath = Path()
        arrowPath.move(to: arrowStart)
        arrowPath.addLine(to: arrowTip)
        arrowPath.addLine(to: arrowStop)
        
        let number: Double = Double.pi / 200 * Double(percent)
        var rotation: CGAffineTransform
        var position: CGAffineTransform
        if clockwise {
            rotation = CGAffineTransform(rotationAngle: Double.pi + number)
            position = rotation.concatenating(CGAffineTransform(translationX: rect.maxX, y:rect.maxY))
        } else {
            rotation = CGAffineTransform(rotationAngle: -number)
            position = rotation.concatenating(CGAffineTransform(translationX: 0, y:rect.maxY))
        }
        
        path.addPath(arrowPath.applying(position))
//        path.addPath(knob.applying(position))
        return path
    }
}

struct GaugeTicks: Shape {
    var clockwise: Bool
    
    func path(in rect: CGRect) -> Path {
        
        var path = Path()
        for number in 0...20 {
            
            var TickPath = Path()
            TickPath.move(to: CGPoint(x:rect.maxX - 10, y: 0))
            if number % 5 == 0 {
                TickPath.addLine(to: CGPoint(x: rect.maxX, y: 0))
            } else {
                TickPath.addLine(to: CGPoint(x: rect.maxX - 5, y: 0))
            }
            let step: Double = Double.pi / 40
            var rotation: CGAffineTransform
            var position: CGAffineTransform
            if clockwise {
                rotation = CGAffineTransform(rotationAngle: Double.pi + step * Double(number))
                position = rotation.concatenating(CGAffineTransform(translationX: rect.maxX, y:rect.maxY))
            } else {
                rotation = CGAffineTransform(rotationAngle: -step * Double(number))
                position = rotation.concatenating(CGAffineTransform(translationX: 0, y:rect.maxY))
            }
            
            path.addPath(TickPath.applying(position))
         }
        
        return path
    }
}

struct Gauge: View {
    @EnvironmentObject var podData: PodGlobalData
    
    var body: some View {
        HStack(alignment: VerticalAlignment.bottom) {
            let visibleWidth = UIScreen.main.bounds.size.width / 3.2
            ZStack {
                GaugeShape(clockwise: true, percent: podData.backPercentage, alarm: true)
                    .stroke(.green, lineWidth: 10)
                    .frame(width: visibleWidth, height: visibleWidth)
                    .aspectRatio(contentMode: .fit)
                
                GaugeShape(clockwise: true, percent: podData.backPercentage, alarm: false)
                    .stroke(.red, lineWidth: 10)
                    .frame(width: visibleWidth, height: visibleWidth)
                    .aspectRatio(contentMode: .fit)
               
                GaugeTicks(clockwise: true)
                    .stroke(.black, lineWidth: 2)
                    .frame(width: visibleWidth, height: visibleWidth)
                GaugeKnob(clockwise: true)
                    .stroke(.black, lineWidth: 4)
                    .frame(width: visibleWidth, height: visibleWidth)
                GaugeArrow(clockwise: true, percent: podData.backPosition)//backPercent
                    .stroke(.black, lineWidth: 1)
                    .frame(width: visibleWidth, height: visibleWidth)
            }
            Image("foot")
                .resizable()
                .frame(width: visibleWidth, height: visibleWidth * 0.8)
                .aspectRatio(contentMode: .fit)
                .onTapGesture {
                    //podData.onReceiveMonitorData(rowBytes: podData.testData)
//                    podData.onReceiveAlarmData(rowBytes: podData.testData)
//                    withAnimation {
//                        podData.backPosition = Int.random(in: 0...90)
//                        podData.frontPosition = Int.random(in: 0...90)
//                    }
                }
            ZStack {
                GaugeShape(clockwise: false, percent: podData.frontPercentage, alarm: true)
                    .stroke(.green, lineWidth: 10)
                    .frame(width: visibleWidth, height: visibleWidth)
                GaugeShape(clockwise: false, percent: podData.frontPercentage, alarm: false)
                    .stroke(.red, lineWidth: 10)
                    .frame(width: visibleWidth, height: visibleWidth)
                GaugeTicks(clockwise: false)
                    .stroke(.black, lineWidth: 2)
                    .frame(width: visibleWidth, height: visibleWidth)
                GaugeKnob(clockwise: false)
                    .stroke(.black, lineWidth: 4)
                    .frame(width: visibleWidth, height: visibleWidth)
                GaugeArrow(clockwise: false, percent: podData.frontPosition)//frontPercent
                    .stroke(.black, lineWidth: 1)
                    .frame(width: visibleWidth, height: visibleWidth)
            }
        }
    }
}
