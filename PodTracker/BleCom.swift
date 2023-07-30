//
//  BleCom.swift
//  PodTracker
//
//  Created by Igor Baglaenko on 2023-06-28.
//

import Foundation
import CoreBluetooth



class PodBleCom: NSObject, ObservableObject, CBCentralManagerDelegate {
    private var SendBleMsg: ReceiveBleData
    private var centralManager: CBCentralManager
    private var discoveredPods = [CBPeripheral] ()  // List of Pods with unsupported IP addr
    private var podSenser: CBPeripheral           // discovered Pod
    
    private let PodMonitoringUUID     = CBUUID(string: "820FC9D1-0C34-4BAF-87FC-758571831943")
   
    private let daillyDataUUID = CBUUID(string: "D823A49A-E194-46F0-85DD-6C043A1CB67B")
    private let weeklyDataUUID = CBUUID(string: "846C755F-BB17-4BDF-B8D5-A778A2C203CB")
    private let opDataUUID     = CBUUID(string: "7C61A878-DEA9-421A-AC8D-1BB3D418CBB2")
    private let notifyUUID     = CBUUID(string: "E7EFD0A2-524B-463C-8F1C-01521B43C349")
    private let podIDUUID      = CBUUID(string: "FDFBB797-6831-4E77-A383-67B5C30CF759")
    
    public var dailyDataCharacteristic  : CBCharacteristic
    public var weeklyDataCharacteristic : CBCharacteristic
    public var opDataCharacteristic     : CBCharacteristic
    public var notifyCharacteristic     : CBCharacteristic
    public var podIdCharacteristic      : CBCharacteristic
    
    override init ( ) {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    // update BLE state
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch central.state {
        case .poweredOn:
            startScan()
            break
        case .poweredOff:
            // Alert user to turn on Bluetooth
            break
        case .resetting:
            // Wait for next state update and consider logging interruption of Bluetooth service
            break
        case .unauthorized:
            // Alert user to enable Bluetooth permission in app Settings
            break
        case .unsupported:
            // Alert user their device does not support Bluetooth and app will not work as expected
            break
        case .unknown:
            // Wait for next state update
            break
        default:
            break
        }
    }
    // Discover Peripheral
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name == "podSensor" {
            if !discoveredPods.contains(peripheral) {
                central.stopScan()
                centralManager.connect(podSenser, options: nil)
            }
        }
    }
    // Connected to Perioheral
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        podSenser = peripheral
        podSenser.delegate = self
        podSenser.discoverServices([PodMonitoringUUID])
        SendBleMsg.onReceiveBleMsg(msgId: .discovering)
    }
    // Failed to connect to peripheral
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // Somthin wrong wtih device. Put it into list of discovered, but not available Pods
        discoveredPods.append(peripheral)
        startScan()
    }
    // POD discom=nnected
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            // Handle error
            return
        }
        SendBleMsg.onReceiveBleMsg(msgId: .disconnected)   // Successfully disconnected
    }
    // Request to start Scan
    func startScan ( ) {
        centralManager.scanForPeripherals(withServices: nil)
        SendBleMsg.onReceiveBleMsg(msgId: .scanning)
    }
    // Request to disconnect POD
    func disconnect(peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
    }
}

extension PodBleCom : CBPeripheralDelegate {
    // Discover Pod service
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            return
        }
        for service in services {
            if service.uuid == PodMonitoringUUID {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    // Discover Pod Characterestics
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            return
        }
        for characteristic in characteristics {
            switch characteristic.uuid {
            case daillyDataUUID:
                dailyDataCharacteristic = characteristic
                break
            case weeklyDataUUID:
                weeklyDataCharacteristic = characteristic
                break
            case opDataUUID    :
                opDataCharacteristic = characteristic
                break
            case notifyUUID    :
                notifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: notifyCharacteristic)
                break
            case podIDUUID     :
                podIdCharacteristic = characteristic
                break
            default:
                break
            }
        }
    }
    // Subscribed to notifiaction
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            // Handle error
            return
        }
        if characteristic == notifyCharacteristic {
            SendBleMsg.onReceiveBleMsg(msgId: .connected)
        }
    }
    // Request write to BLE characteristic
    func writeOpData(value: Data) {
        podSenser.writeValue(value, for: opDataCharacteristic, type: .withResponse)
     }
    // Confirm write complete
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            // Handle error
            return
        }
        guard let value = characteristic.value else {
            return
        }
        if value[0] == 0x01 {
            SendBleMsg.onReceiveBleMsg(msgId: .sentSyncPodData)
        }
        else if value[0] == 10 {
            SendBleMsg.onReceiveBleMsg(msgId: .sentTransfer)
        }
        else if value[0] == 2 {
            // Monitor mode set to true
        }
        else if value[0] == 3 {
            // Monitor mode set to false
        }
    }
    // Request read BLE characteristic
    func readValue(characteristic: CBCharacteristic) {
        podSenser.readValue(for: characteristic)
    }
    // Received read characteristic data
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            // Handle error
            return
        }
        guard let value = characteristic.value else {
            return
        }
        SendBleMsg.onReceiveBleData(rowData: value)
    }
}

//class BleCom  {
//
//
//
//    var podData: PodGlobalData
//    var podIdData     = Data (repeating: 0, count: 53)
//    var podDailyData  = Data()
//    var txIndex       = 0
//    var timeCounter   = 0
//    var currentHour   = 13
//    var CurrentIndex  = 136
//
//    var back:Int      = 0
//    var front:Int     = 0
//    var dayStep: Int  = 0
//    var dayAlert: Int = 0
//    var weekStep:Int  = 0
//    var weekAlert:Int = 0
//
//    enum bleStates {
//        case connecting,
//             services,
//             conneceted,
//             readPodId,
//             readDailyData,
//             readWeeklyData,
//             monitoring
//    }
//    var bleState: bleStates
//
//    init ( podGlobalData: PodGlobalData ) {
//        podData = podGlobalData
//        bleState = bleStates.connecting
//        // POD ID data
//        buildPodIdData ()
//        // POD Daily data
//        buildDailyData ()
//
//        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in
//            if self.podData.bleData.completeMonitor {
//                timer.invalidate()
//            }
//            else {
//                if self.generateStepsAndAlarms() {
//                    let bytes = self.buildAlarmData()
//                    self.podData.onReceiveAlarmData(rowBytes: bytes)
//                }
//                self.onReceiveBleMsg()
//            }
//        })
//
//    }
//
//    var switchIndex: [Int] = [0,0,0,0,0]
//    var margin: [Int] = [0,0,0,0,0]
//    var period = 0
//
//    func generateStepsAndAlarms() -> Bool {
//        var generateAlarm: Bool = false
//        timeCounter += 1
//        currentHour += 1
//        if currentHour == 24 {
//            currentHour = 0
//            CurrentIndex += 1
//            dayStep = 0
//            dayAlert = 0
//            weekStep = 0
//            weekAlert = 0
//
//            period = 0
//            for _ in 0...4 {
//                if CurrentIndex < switchIndex[period] {
//                    break
//                }
//                period += 1
//            }
//
//        }
//        if bleState == bleStates.monitoring {
//            if timeCounter % 5 == 0 {
//                back  = Int.random(in: 0...100)     // backPercent;
//                front = Int.random(in: 0...100)     // frontPercent; let alarm = Int.random(in: 0...5)
//            }
//            else {
//                back  = Int.random(in: 0...margin[period])     // backPercent;
//                front = Int.random(in: 0...margin[period])     // frontPercent; let alarm = Int.random(in: 0...5)
//            }
//            if back > margin[period] || front > margin[period] {
//                generateAlarm = true
//            }
//            dayStep += 1
//            weekStep += 1
//            if generateAlarm {
//                dayAlert += 1
//                weekAlert += 1
//            }
//        }
//        return generateAlarm
//    }
//    func buildPodIdData () {
//        podIdData.replaceSubrange(0...6, with: [0x31,0x32,0x30,0x36,0x32,0x33,0])
//        podIdData.replaceSubrange(7...24,with: [0x31,0x31,0x3A,0x32,0x32,0x3A,0x32,0x32,0x3A,0x32,0x32,0x3A,0x32,0x32,0x3A,0x32,0x32,0])
//        podIdData[25] = UInt8(67)
//        let startYear = 2023
//        podIdData[30] = (UInt8(startYear & 0xFF))
//        podIdData[31] = (UInt8(startYear >> 8))
//        let day = 122
//        podIdData[32] = (UInt8(day & 0xFF))
//        podIdData[33] = (UInt8(day >> 8))
//        podIdData[38] = 45      //duration;
//        podIdData[39] = 15      //frontPercent;
//        podIdData[40] = 15      //backPercent;
//        podIdData[41] = 45      //duration;
//        podIdData[42] = 20      //frontPercent;
//        podIdData[43] = 20      //backPercent;
//        podIdData[44] = 55      //duration;
//        podIdData[45] = 25      //frontPercent;
//        podIdData[46] = 25      //backPercent;
//        podIdData[47] = 5     //duration;
//        podIdData[48] = 30      //frontPercent;
//        podIdData[49] = 30      //backPercent;
//
//        switchIndex[0] = Int(podIdData[38])
//        switchIndex[1] += switchIndex[0] + Int(podIdData[41])
//        switchIndex[2] += switchIndex[1] + Int(podIdData[44])
//        switchIndex[3] += switchIndex[2] + Int(podIdData[47])
//        switchIndex[4] += switchIndex[3] + Int(podIdData[50])
//
//        margin[0] = Int(podIdData[39])
//        margin[1] = Int(podIdData[42])
//        margin[2] = Int(podIdData[45])
//        margin[3] = Int(podIdData[48])
//        margin[4] = Int(podIdData[51])
//
//    }
//    func buildDailyData () {
//        podDailyData.append(UInt8(currentHour))
//        podDailyData.append(UInt8(0))
//        for _ in 0...currentHour {
//            dayStep = Int.random(in: 0...100)
//            podDailyData.append(UInt8(dayStep & 0xFF))
//            podDailyData.append(UInt8(dayStep >> 8))
//            dayAlert = Int.random(in: 0...dayStep)
//            podDailyData.append(UInt8(dayAlert & 0xFF))
//            podDailyData.append(UInt8(dayAlert >> 8))
//        }
//        podDailyData.append(contentsOf: [UInt8](repeating: 0, count: (23 - currentHour) * 4))
//    }
//    func buildWeeklyData (startIndx: Int) -> Data{
//        var podWeeklyData = Data()
//        // POD Weekly data1
//        var stopIndx: Int = CurrentIndex - startIndx
//        if stopIndx > 126 {
//            stopIndx = 126
//        }
//        var size: Int = stopIndx * 4
//        if startIndx == 0 {
//            size += 2
//        }
//        podWeeklyData.append(UInt8(size & 0xFF))
//        podWeeklyData.append(UInt8(size >> 8))
//        if startIndx == 0 {
//            podWeeklyData.append(UInt8(CurrentIndex & 0xFF))
//            podWeeklyData.append(UInt8(CurrentIndex >> 8))
//        }
//        for _ in 0...stopIndx {
//            weekStep = Int.random(in: 0...1000)
//            podWeeklyData.append(UInt8(weekStep & 0xFF))
//            podWeeklyData.append(UInt8(weekStep >> 8))
//            weekAlert = Int.random(in: 0...weekStep)
//            podWeeklyData.append(UInt8(weekAlert & 0xFF))
//            podWeeklyData.append(UInt8(weekAlert >> 8))
//        }
//        return podWeeklyData
//    }
//    func buildMonitorData( ) -> Data {
//        var data = Data ()
//        data.append(UInt8(0x44)) // msgID
//        data.append(UInt8(100))     // batteryLevel;
//        data.append(UInt8(UInt8(back)))     // backPercent;
//        data.append(UInt8(UInt8(front)))     // frontPercent;
//        data.append(UInt8(currentHour))     // curHour;
//        data.append(UInt8(dayStep & 0xFF))     // lsb_DaySteps;
//        data.append(UInt8(dayStep >> 8 ))     // msb_DaySteps;
//        data.append(UInt8(dayAlert & 0xFF))     // lsb_DayAlarms;
//        data.append(UInt8(dayAlert >> 8 ))     // msb_DayAlarms;
//        data.append(UInt8(CurrentIndex & 0xFF))     // CurIndx;
//        data.append(UInt8(weekStep & 0xFF))     // lsb_TotalSteps;
//        data.append(UInt8(weekStep >> 8))     // msb_TotalSteps;
//        data.append(UInt8(weekAlert & 0xFF))     // lsb_TotalAlarms;
//        data.append(UInt8(weekAlert >> 8))     // msb_TotalAlarms;
//        return data
//    }
//    func buildStatusData ( indx: Int) -> String {
//        let message = ["Connecting...", "Discovering POD Services"]
//
//        return message[indx]
//    }
//    func buildAlarmData () -> Data {
//        var data = Data()
//        data.append(UInt8(back))
//        data.append(UInt8(front))
//        return data
//    }
//}
