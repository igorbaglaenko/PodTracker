//
//  PodData.swift
//  PodTracker
//
//  Created by Igor Baglaenko on 2023-05-28.
//

import Foundation
struct PodAlert:       Identifiable {
    var entry:         String
    var alertsPercent: Double
    var stepsPercent:  Double
    var alerts:        String
    var steps:         String
    var id = UUID()
}
struct BearingProtocol {
    var start: String
    var end:   String
    var front: String
    var back:  String
}
enum BleMsgId: UInt8 {
    case wrongvalue      = 0x00
    case scanning        = 0x01
    case discovering     = 0x02
    case connected       = 0x03
    case disconnected    = 0x04
    case sentSyncPodData = 0x05
    case sentTransfer    = 0x06
    case sentMonitor     = 0x07
    case sentMute        = 0x08
}
enum bleStates {
    case connecting,
         readPodId,
         syncPodData,
         readDailyData,
         requestTransfer,
         readWeeklyData,
         connected,
         monitoring,
         disconnected
}
protocol ReceiveBleData {
    func onBLEReceiveData (rowData: Data)
    func onBLEReceiveMsg  (msgId: BleMsgId )
    
}
class PodGlobalData : ObservableObject , ReceiveBleData {
    let day  = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
    let hour = ["12am","1am","2am","3am","4am","5am","6am","7am",
                "8am","9am","10am","11am","12pm","1pm","2pm","3pm",
                "4pm","5pm","6pm","7pm","8pm","9pm","10pm","11pm"]
    let hours = ["12am - 7am",
                 "8am - 3pm",
                 "4pm - 11pm"]
    
    @Published var muteAlarm  :      String =  UserDefaults.standard.string(forKey: "MUTE_POD_MOD") ?? "Mute Pod Alarm"
    
    @Published var connectionStatus: String = "Disconnected"
    @Published var batteryStatus:    String = "Battery Level: 100% "
    @Published var codeVersion:      String = ""
    @Published var macAddress   :    String = ""
    @Published var frontPercentage:  Double = 0
    @Published var backPercentage:   Double = 0
    @Published var frontPosition:    Int    = 0
    @Published var backPosition:     Int    = 0
    @Published var overloadMsg:      String = "   "
    @Published var maxAllowedTitle:  String = "  Max Allowed:"
    @Published var maxAllowed:       String = "   "
    @Published var currentPeriod:    String = "   "
    @Published var periodStart:      String = "   "
    @Published var periodEnd:        String = "   "
    @Published var periodDuration:   Double = 100
    @Published var periodComplete:   Double = 100
    @Published var alertsNo:         String = "0"
    @Published var stepsNo:          String = "0"
    @Published var range:            String = ""
    @Published var pickerID:         Int    = 1
    @Published var barData =         [PodAlert]()
    @Published var schedule =        [BearingProtocol] ()
    @Published var endDate:          String = ""
    @Published var terminateApp:     Bool   = false
    @Published var terminateMsg:     String = ""
    
    var bleData          = PodBleData()
    var weekIndex:   Int = 0
    var dayIndex:    Int = 0
    let dayInterval: Int = 60 * 60 * 24
    var timer:    Timer? = nil
    var txIndex:     Int = 0
    
    var bleState: bleStates
    init ( ) {
        bleState = .disconnected
        let entry = BearingProtocol (start: "Start",
                                     end:   "End",
                                     front: "Front",
                                     back:  "Back" )
        schedule.append(entry)
        for _ in 0...4 {
            let entry = BearingProtocol (start: "",
                                         end:   "",
                                         front: "",
                                         back:  "" )
            schedule.append(entry)
        }
        bleData.podBLE.SendBleMsg = self
    }
    func changeMuteAlarm () {
        let mode = muteAlarm == "Mute Pod Alarm"
        muteAlarm = mode ? "Activate Pod Alarm" : "Mute Pod Alarm"
        bleData.writeMuteAlarm(state: mode)
        UserDefaults.standard.set(muteAlarm, forKey: "MUTE_POD_MOD")
    }
    // BLE State Machine
    func onBLEReceiveMsg(msgId: BleMsgId) {
        // POD connected. Requst read POD_ID
        if msgId == .connected {
            connectionStatus = "Verifying POD id"
            bleData.readPodID()
            bleState = .readPodId
        }
        // POD synchronized. Request read DAILY_DATA
        if msgId == .sentSyncPodData {
            bleData.readDailyData()
            bleState = .readDailyData
        }
        // POD ready for transfering data. Request read WEEKLY_DATA
        else if msgId == .sentTransfer {
            bleData.readWeeklyData()
            bleState = .readWeeklyData
        }
        // POD disconnected
        else if msgId == .disconnected {
            if bleData.completeMonitor {
                connectionStatus = "Disconected"
            }
            else {
                bleData.startScan()
            }
        }
        else if msgId == .sentMonitor {
            let mode = muteAlarm == "Activate Pod Alarm"
            bleData.writeMuteAlarm(state: mode)
        }
        // Display connection status
        else if msgId != .wrongvalue {
            bleData.setStatusData(status: msgId)
            connectionStatus = bleData.statusMsg
        }
    }
    func onBLEReceiveData(rowData: Data) {
        switch bleState {
        case .readPodId:
            if rowData.count == 55 {
                onReceivePodID(rowBytes: rowData)
                // Verify POD ID. Request Sync Time and Data
                if bleData.validatePodData() {
                    bleState = .syncPodData
                    bleData.writeSyncData()
                }
                // POD not recognized. Disconnect and shutdown
                else {
                    // stop scanning
                    // output message "Pod is not supported"
                    terminateApp = true
                    terminateMsg = "Please upgrade Pod Firmware"
                    bleData.completeMonitor = true
                    bleState = .disconnected
                    bleData.disconnectPod ( )
                }
            }
            break
        case .readDailyData:
            onReceiveDailyData(rowBytes: rowData)
            txIndex = 0;
            bleState = .requestTransfer
            bleData.writeTransferData( startIndx: txIndex )
            break
        case .readWeeklyData:
            txIndex = onReceiveTotalData(rowBytes: rowData, startIndex: txIndex)
            if txIndex == 0 {
                // it is possible that monitoring period complete
                if bleData.completeMonitor {
                    bleState = .disconnected
                    bleData.disconnectPod()
                }
                else {
                    bleState = .monitoring
                    bleData.writeMonitorMode(state: true)
                }
            }
            else {
                bleState = .requestTransfer
                bleData.writeTransferData(startIndx: txIndex)
            }
            break
        case .monitoring:
            if rowData[0] == 0x44 {
                // it is possible that monitoring period complete
                onReceiveMonitorData(rowBytes: rowData)
                if bleData.completeMonitor {
                    bleState = .disconnected
                    bleData.disconnectPod()
                }
            }
            else if rowData[0] == 0x41 {
                onReceiveAlarmData(rowBytes: rowData)
            }
            break
        default:
            break;
        }
    }
    // Update BLE Data
    func onReceivePodID(rowBytes: Data) {
        bleData.setPodIdData(rowBytes: rowBytes)
        batteryStatus    = "Battery Level: \(bleData.batteryLevel)%"
        connectionStatus = "Receiving Data ..."
        codeVersion      = bleData.codeVersion
        macAddress       = bleData.macAddr
       
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd"
        dateFormatter.locale = Locale(identifier: "en_US")
        
        var noOfDays = 0
        for i in 0...4 {
            if Int(bleData.duration[i]) > 0 {
                let startdate = bleData.startDate.addingTimeInterval( Double(noOfDays * dayInterval))
                noOfDays += Int(bleData.duration[i]) - 1
                let enddate   = bleData.startDate.addingTimeInterval( Double(noOfDays * dayInterval))
                noOfDays += 1
                schedule[i + 1].start =  dateFormatter.string(from: startdate)
                schedule[i + 1].end   =  dateFormatter.string(from: enddate)
                schedule[i + 1].front =  "\(bleData.frontMargin[i])%"
                schedule[i + 1].back =   "\(bleData.backMargin[i])%"
                
            }
        }
        let enddate = bleData.startDate.addingTimeInterval( Double(noOfDays * dayInterval))
        endDate = dateFormatter.string(from: enddate)
    }
    func onReceiveDailyData ( rowBytes: Data ) {
        bleData.setDailyData(rowBytes: rowBytes)
        connectionStatus = "Receiving Data ... 25%"
    }
    func onReceiveTotalData (rowBytes: Data, startIndex: Int) -> Int {
        var copyIndex = startIndex
        if bleData.setTotalData(rowBytes: rowBytes, startIndex: &copyIndex ) {
            let progress = copyIndex * 100 / bleData.currentIndex
            connectionStatus = "Receiving Data ... \(progress)%"
            return copyIndex
        }
        // Status message
        connectionStatus = "Connected to POD"
        // Battery level
        batteryStatus    = "Battery Level: \(bleData.batteryLevel)%"
        // Gauge margins
        frontPercentage = Double(bleData.frontPercentage)
        backPercentage  = Double(bleData.backPercentage)
        // Period data
        setPeriodData()
        periodComplete = Double(bleData.currentIndex - bleData.periodStartIndx + 1)
        // Bar data
        weekIndex = ((bleData.currentIndex + bleData.firstDayIndex) / 7 ) * 7
        pickerID = 1
        setBarType(lastPeriod: true)
        return 0
    }
    func onReceiveMonitorData ( rowBytes: Data ) {
        // Update Period data
        if bleData.setMonitoringData(rowBytes: rowBytes) {
            if bleData.nextPeriod || bleData.completeMonitor {
                setPeriodData()
            }
            if bleData.completeMonitor {
                periodDuration = 100
                periodComplete = 100
            }
            else {
                periodComplete = Double(bleData.currentIndex - bleData.periodStartIndx + 1)
            }
        }
        // Battery level
        batteryStatus    = "Battery level \(bleData.batteryLevel)%"
        // Gauge indicator
        if bleData.completeMonitor {
            backPosition  = 0
            frontPosition = 0
            pickerID = 1
            setBarType(lastPeriod: true)
        }
        else {
            backPosition  = bleData.backPosition
            frontPosition = bleData.frontPosition
            setBarType(lastPeriod: false)
        }
    }
    func onReceiveAlarmData (rowBytes: Data) {
        bleData.setAlarmData(rowBytes: rowBytes)
        // Gauge indicator
        backPosition  = bleData.backAlert
        frontPosition = bleData.frontAlert
        // Overload message
        if backPosition > bleData.backPercentage && frontPosition > bleData.frontPercentage {
            var overload = backPosition + frontPosition
            if overload > 100 {
                overload = 100
            }
            overloadMsg = "Total Overload!   \(overload)%"
        }
        else if backPosition > bleData.backPercentage {
            overloadMsg = "Back Overload!   \(backPosition)%"
        }
        else if frontPosition > bleData.frontPercentage {
            overloadMsg = "Front Overload!   \(frontPosition)%"
        }
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false, block: { timer in
                self.overloadMsg = "   "
                self.timer = nil
            })
        }
    }
    
    
    // Request to update data when switch between 'weekly' and 'today'
    func setBarType ( lastPeriod: Bool ) {
        if pickerID == 1 {
            if lastPeriod {
                weekIndex = ((bleData.currentIndex + bleData.firstDayIndex) / 7 ) * 7
            }
            setWeeklyBarData()
        }
        else {
            if lastPeriod {
                dayIndex = (bleData.currentHour / 8) * 8
            }
            setHourlyBarData()
        }
        setAlertsAndSteps()
        setRangeString()
    }
    // Request to update data when slide over the bar graph
    func setStartIndex (dir: Int ) {
        if pickerID == 1 {
            let indx = weekIndex + dir * 7
            if indx >= 0 && indx <= bleData.currentIndex {
                weekIndex = indx
            }
        }
        else {
            let indx = dayIndex + dir * 8
            if indx >= 0 && indx <= bleData.currentHour {
                dayIndex = indx
            }
        }
        setAlertsAndSteps()
        setRangeString()
        if pickerID == 1 {
            setWeeklyBarData()
        }
        else {
            setHourlyBarData()
        }
    }
    // Request to update total steps and alerts
    func setAlertsAndSteps ( ) {
        var sumAlerts = 0
        var sumSteps  = 0
        switch pickerID
        {
        case 1:
            for i in weekIndex...weekIndex + 6 {
                sumAlerts += bleData.totalAlerts[i]
                sumSteps  += bleData.totalSteps[i]
            }
            break
        case 2:
            for i in dayIndex...dayIndex + 7 {
                sumAlerts += bleData.dailyAlerts[i]
                sumSteps  += bleData.dailySteps[i]
            }
            break
        default:
            break
        }
        alertsNo = String(format: "%4d", sumAlerts)
        stepsNo  = String(format: "%4d", sumSteps)//String(sumSteps)
    }
    // Request to update weekly bar graph
    func setWeeklyBarData( ) {
        barData = [PodAlert] ()
        for indx in weekIndex...weekIndex + 6 {
            var alert: Double  = Double(bleData.totalAlerts[indx]) / Double(bleData.totalSteps[indx])
            if alert > 0 && alert < 0.05 {
                alert = 0.05
            }
            else if alert < 1 && alert > 0.95 {
                alert = 0.95
            }
            let step: Double   = 1 - alert
            var alertStr = " "
            var stepStr = " "
            if bleData.totalAlerts[indx] != 0 {
                alertStr = String(bleData.totalAlerts[indx])
            }
            if bleData.totalSteps[indx] - bleData.totalAlerts[indx] != 0 {
                stepStr = String(bleData.totalSteps[indx] - bleData.totalAlerts[indx])
            }
            barData.append(PodAlert.init(entry:         day[indx % 7],
                                         alertsPercent: alert,
                                         stepsPercent:  step,
                                         alerts:        alertStr,
                                         steps:         stepStr
                                        )
            )
        }
    }
    // Request to update hourly bar graph
    func setHourlyBarData( ) {
        barData = [PodAlert] ()
        
        for indx in dayIndex...dayIndex + 7 {
            var alert: Double  = Double(bleData.dailyAlerts[indx]) / Double(bleData.dailySteps[indx ])
            if alert > 0 && alert < 0.05 {
                alert = 0.05
            }
            else if alert < 1 && alert > 0.95 {
                alert = 0.95
            }
            let step: Double   = 1 - alert
            
            var alertStr = " "
            var stepStr = " "
            if bleData.dailyAlerts[indx] != 0 {
                alertStr = String(bleData.dailyAlerts[indx])
            }
            if bleData.dailySteps[indx] - bleData.dailyAlerts[indx] != 0 {
                stepStr = String(bleData.dailySteps[indx] - bleData.dailyAlerts[indx])
            }
            barData.append(PodAlert.init(entry:         hour[indx],
                                         alertsPercent: alert,
                                         stepsPercent:  step,
                                         alerts:        alertStr,
                                         steps:         stepStr
                                        )
            )
        }
        
    }
    // request to update range of the bar presentation
    func setRangeString ( ) {
        if pickerID == 1 {
            let startdate = bleData.startDate.addingTimeInterval( Double((weekIndex - bleData.firstDayIndex) * dayInterval))
            let enddate   = bleData.startDate.addingTimeInterval( Double((weekIndex + 6 - bleData.firstDayIndex) * dayInterval))
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM dd"
            dateFormatter.locale = Locale(identifier: "en_US")
            range = dateFormatter.string(from: startdate) + " - " +
            dateFormatter.string(from: enddate)
        }
        else {
            range = hours[dayIndex / 8]
        }
    }
    // request to update period related data
    func setPeriodData ( ) {
        let start = bleData.startDate.addingTimeInterval( Double(bleData.periodStartIndx * dayInterval))
        let end   = bleData.startDate.addingTimeInterval( Double((bleData.periodEndIndx - 1) * dayInterval))
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "MMM dd"
        if bleData.completeMonitor {
            overloadMsg     = ""
            maxAllowedTitle = "    "
            maxAllowed      = "    "
            currentPeriod   = "Weight Bearing Protocol Complete"
            periodStart    = dateFormatter.string(from: bleData.startDate)
            periodEnd      = dateFormatter.string(from: end)
            periodDuration = 100
            periodComplete = 100
        }
        else {
            maxAllowed     = " Front:\(bleData.frontPercentage)% Back:\(bleData.backPercentage)%"
            currentPeriod  = "Current Period \(bleData.periodNumber)"
            periodStart    = dateFormatter.string(from: start)
            periodEnd      = dateFormatter.string(from: end)
            periodDuration = Double(bleData.periodDuration)
            periodComplete = Double(bleData.periodEndIndx - bleData.currentIndex + 1)
        }
    }
    // Request to update gauge indicator
    func setGaugePosition () {
        backPosition  = bleData.backPosition
        frontPosition = bleData.frontPosition
    }
}
