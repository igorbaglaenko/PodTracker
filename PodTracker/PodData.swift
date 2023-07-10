//
//  PodData.swift
//  PodTracker
//
//  Created by Igor Baglaenko on 2023-05-28.
//

import Foundation
struct PodAlert: Identifiable {
    var entry:  String
    var alertsPercent: Double
    var stepsPercent:  Double
    var alerts: String
    var steps:  String
    var id = UUID()
}
struct BearingProtocol {
    var start: String
    var end:   String
    var front: String
    var back:  String
}
class PodGlobalData : ObservableObject {
    let day  = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
    let hour = ["12am","1am","2am","3am","4am","5am","6am","7am",
                "8am","9am","10am","11am","12pm","1pm","2pm","3pm",
                "4pm","5pm","6pm","7pm","8pm","9pm","10pm","11pm"]
    let hours = ["12am - 7am",
                 "8am - 3pm",
                 "4pm - 11pm"]
    
    @Published var connectionStatus: String = "Scanning POD devices"
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
    
    var bleData          = PodBleData()
    var weekIndex:   Int = 0
    var dayIndex:    Int = 0
    let dayInterval: Int = 60 * 60 * 24
    var timer:    Timer? = nil
    
    init ( ) {
        let _ = BleCom(podGlobalData: self)
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
    }
    
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
                endDate = dateFormatter.string(from: enddate)
            }
        }
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
        setBarType()
        return 0
    }
    func onReceiveMonitorData ( rowBytes: Data ) {
        // Update Period data
        if bleData.setMonitoringData(rowBytes: rowBytes) {
            if bleData.nextPeriod || bleData.completeMonitor {
                setPeriodData()
            }
            let newWeekIndex = ((bleData.currentIndex + bleData.firstDayIndex) / 7 ) * 7
            if weekIndex == newWeekIndex - 7 {
                weekIndex = newWeekIndex
            }
            // reset daily Index
            dayIndex = 0
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
            setBarType()
        }
        else {
            backPosition  = bleData.backPosition
            frontPosition = bleData.frontPosition
            setBarType()
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
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false, block: { timer in
                self.overloadMsg = "   "
                self.timer = nil
            })
        }
    }
    func onReceiveStatusData ( status: String) {
        connectionStatus = status
    }
    // Request to update data when switch between 'weekly' and 'today'
    func setBarType ( ) {
        setAlertsAndSteps()
        setRangeString()
        if pickerID == 1 {
            setWeeklyBarData()
        }
        else {
            setHourlyBarData()
        }
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
            overloadMsg     = "Tracking stopped "
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
