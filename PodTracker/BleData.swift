//
//  BleData.swift
//  PodTracker
//
//  Created by Igor Baglaenko on 2023-06-14.
//

import Foundation
import SwiftUI


class PodBleData  {
    @EnvironmentObject var podData: PodGlobalData
    // Presentation Data
    var batteryLevel:     Int  = 0  // battery level
    var frontPercentage:  Int  = 0  // front max percent for period
    var backPercentage:   Int  = 0  // back max percent for period
    var frontPosition:    Int  = 0  // Gauge indicator
    var backPosition:     Int  = 0  // Gauge indocator
    var frontAlert:       Int  = 0  // immediate front alert
    var backAlert:        Int  = 0  // immediate back alert
    var periodNumber:     Int  = 0  // immediate back alert
    var periodStartIndx:  Int  = 0  // period start day
    var periodEndIndx:    Int  = 0  // period end day
    var periodDuration:   Int  = 0  // period total days
    var codeVersion:   String  = "" // version (7 bytes)
    var macAddr:       String  = "" // MAC address (18 bytes)
    var statusMsg:     String  = "Disconected"
    var dailySteps             = [Int](repeating: 0, count: 24)        // daily steps array
    var dailyAlerts            = [Int](repeating: 0, count: 24)        // daily alerts array
    var totalSteps             = [Int](repeating: 0, count: 7 * 54 + 12) // weekly steps array
    var totalAlerts            = [Int](repeating: 0, count: 7 * 54 + 12) // weekly alerts array
    
    // POD Data
    var  duration              = [UInt8](repeating: 0, count: 5)        // period durations
    var  frontMargin           = [UInt8](repeating: 0, count: 5)        // period front margim
    var  backMargin            = [UInt8](repeating: 0, count: 5)        // period back margin
    var  startDate             = Date.now                               // start Date
    var  firstDayIndex:   Int  = 0 // first day index alligned to week start
    var  currentHour:     Int  = 0 // current index in Daily data
    var  currentIndex:    Int  = 0 // current index in Weekly data alligned to Sunday
    var  lastDayIndex:    Int  = 0
    var  nextPeriod:     Bool  = false
    var  completeMonitor:Bool  = false
    
    var podBLE = PodBleCom()
    // Request POD_ID
    func readPodID ( ) {
        if let podId = podBLE.podIdCharacteristic {
            podBLE.readValue(characteristic: podId)
        } 
    }
    // Request SYNC_POD
    func writeSyncData ( ) {
        let data = Data()
        podBLE.writeOpData(value: data)
    }
    // Request DAILY_DATA
    func readDailyData ( ) {
        
    }
    // Request start transfer Data
    func writeTransferData (startIndx: Int ){
        
    }
    // Request TOTAL_DATA
    func readWeeklyData ( ) {
        
    }
    func disconnectPod ( ) {
        
    }
    // parse POD_ID_DATA
    func setPodIdData ( rowBytes: Data) {
        var src = [UInt8](rowBytes[0...6])
        codeVersion = String(decoding: src, as: UTF8.self)
        src = [UInt8](rowBytes[7...24])
        macAddr = String(decoding: src, as: UTF8.self)
        batteryLevel = Int(rowBytes[25])
      
        var components = DateComponents()
        var offset = 30
        let year = getShort(data: rowBytes,offset: &offset)
        components.year = year
        let day = getShort(data: rowBytes,offset: &offset)
        components.day  = day
        let calendar = Calendar.current
        startDate = calendar.date(from: components) ?? Date.now
        firstDayIndex = calendar.component(.weekday, from: startDate) - 1
        //components = calendar.dateComponents([.weekday], from: startDate)
        //firstDayIndex = components.weekday//.weekday ?? 0
        
        var indx = 0
        lastDayIndex = 0
        for i in stride(from: 38, to: 50, by: 3) {
            duration[indx] = rowBytes[i]
            lastDayIndex += Int(duration[indx])
            frontMargin[indx] = rowBytes[i+1]
            backMargin[indx] = rowBytes[i+2]
            indx += 1
        }
    }
    // parse DAILY_DATA
    func setDailyData (rowBytes: Data) {
        var offset = 0
        currentHour = getShort(data: rowBytes, offset: &offset)
        for i in 0...23 {
            dailySteps[i]  = getShort(data: rowBytes, offset: &offset)
            dailyAlerts[i] = getShort(data: rowBytes, offset: &offset)
        }
    }
    // parse TOTAL_DATA
    func setTotalData (rowBytes: Data, startIndex: inout Int) -> Bool {
        var offset = 0
        let length = getShort(data: rowBytes, offset: &offset)
        var stopIndex = startIndex
        if startIndex == 0 {
            currentIndex = getShort(data: rowBytes, offset: &offset)
            getPeriodData( index: currentIndex )
            stopIndex += (length - 2) / 4
        }
        else {
            stopIndex  += length / 4
        }
        while  startIndex < stopIndex {
            totalSteps [startIndex + firstDayIndex]  = getShort(data: rowBytes, offset: &offset)
            totalAlerts[startIndex + firstDayIndex] = getShort(data: rowBytes, offset: &offset)
            startIndex += 1
        }
        return startIndex < currentIndex
    }
    // parse MONITORING_DATA
    func setMonitoringData ( rowBytes: Data ) -> Bool{
        var nextDay = false
        nextPeriod  = false
        batteryLevel = Int(rowBytes[1])
        backPosition = Int(rowBytes[2])
        frontPosition = Int(rowBytes[3])
        let hour = Int(rowBytes[4])
        if hour == 0 && currentHour > 0 {
            // new day. Reset daily data
            for i in 0...23 {
                dailySteps[i]  = 0
                dailyAlerts[i] = 0
            }
        }
        currentHour = hour
        let indx = Int(rowBytes[9])
        if !completeMonitor {
            if indx == lastDayIndex {
                completeMonitor = true
                nextPeriod = true
                nextDay = true
            }
            else {
                if currentIndex != indx {
                    if indx == periodEndIndx {
                        getPeriodData(index: indx)
                        nextPeriod = true
                    }
                    nextDay = true
                }
                currentIndex = indx
                var offset = 5
                dailySteps[currentHour] = getShort(data: rowBytes, offset: &offset)
                dailyAlerts[currentHour] = getShort(data: rowBytes, offset: &offset)
                offset = 10
                totalSteps[currentIndex + firstDayIndex] = getShort(data: rowBytes, offset: &offset)
                totalAlerts[currentIndex + firstDayIndex] = getShort(data: rowBytes, offset: &offset)
            }
        }
        return nextDay
    }
    // parse ALARM_DATA
    func setAlarmData ( rowBytes: Data) {
        backAlert = Int(rowBytes[0])
        frontAlert = Int(rowBytes[1])
    }
    // parse STATUS_EVENT
    func setStatusData (status: BleMsgId) {
        switch status {
        case .scanning:
            statusMsg = "Scanning POD devices"
            break;
        case .discovering:
            statusMsg = "Discovering Services"
            break;
        case .connected:
            statusMsg = "Connected"
            break
        case .disconnected:
            // bring BLE to scannig mode
            statusMsg = "Disconnected"
            break
        default:
            statusMsg = "No POD detected"
            break
        }
    }
   
    // Utility functions
    func getPeriodData ( index: Int ) {
        var switchIndx = 0
        var startIndx  = 0
        for i in 0...4 {
            switchIndx += Int(duration[i])
            if ( index < switchIndx) {
                periodNumber    = i+1
                periodStartIndx = startIndx
                periodEndIndx   = switchIndx
                frontPercentage = Int(frontMargin[i])
                backPercentage  = Int(backMargin[i])
                periodDuration  = Int(duration[i])
                break
            }
            startIndx = switchIndx
        }
//        completeMonitor = index == lastDayIndex
    }
    func getShort ( data: Data, offset: inout Int) -> Int {
        let res: Int = (Int(data[offset + 1]) << 8 ) + Int(data[offset])
        offset += 2
        return res
    }
    func validatePodData ( ) -> Bool {
        // compare Threshold version
        // compare MAC address
        return true
    }
}
