//
//  BleCom.swift
//  PodTracker
//
//  Created by Igor Baglaenko on 2023-06-28.
//

import Foundation
import CoreBluetooth



class PodBleCom: NSObject, CBCentralManagerDelegate {
    public var  SendBleMsg:      ReceiveBleData?
    private var centralManager:  CBCentralManager!
    private var discoveredPods = [CBPeripheral] ()  // List of Pods with unsupported IP addr
    private var podSenser:       CBPeripheral?          // discovered Pod
    
    private let PodMonitoringUUID = CBUUID(string: "820FC9D1-0C34-4BAF-87FC-758571831943")
   
    private let daillyDataUUID = CBUUID(string: "D823A49A-E194-46F0-85DD-6C043A1CB67B")
    private let weeklyDataUUID = CBUUID(string: "846C755F-BB17-4BDF-B8D5-A778A2C203CB")
    private let opDataUUID     = CBUUID(string: "7C61A878-DEA9-421A-AC8D-1BB3D418CBB2")
    private let notifyUUID     = CBUUID(string: "E7EFD0A2-524B-463C-8F1C-01521B43C349")
    private let podIDUUID      = CBUUID(string: "FDFBB797-6831-4E77-A383-67B5C30CF759")
    
 
    public var dailyDataCharacteristic  : CBCharacteristic!
    public var weeklyDataCharacteristic : CBCharacteristic!
    public var opDataCharacteristic     : CBCharacteristic!
    public var notifyCharacteristic     : CBCharacteristic!
    public var podIdCharacteristic      : CBCharacteristic!
    
    public var sentMsgId: BleMsgId = .wrongvalue
    override init ( ) {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    // update BLE state
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch central.state {
        case .poweredOn:
            central.scanForPeripherals(withServices: nil )//[PodMonitoringUUID])
            SendBleMsg?.onBLEReceiveMsg(msgId: .scanning)
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
                //central.stopScan()
                podSenser = peripheral
                centralManager.connect(peripheral, options: nil)
            }
        }
    }
    // Connected to Perioheral
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        //podSenser = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([PodMonitoringUUID])
        SendBleMsg?.onBLEReceiveMsg(msgId: .discovering)
    }
    // Failed to connect to peripheral
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // Something wrong wtih device. Put it into list of discovered, but not available Pods
        //discoveredPods.append(peripheral)
        startScan()
    }
    // POD discom=nnected
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
//        if let error = error {
//            // Handle error
//            return
//        }
        SendBleMsg?.onBLEReceiveMsg(msgId: .disconnected)   // Successfully disconnected
        startScan()
    }
    // Request to start Scan
    func startScan ( ) {
        centralManager.scanForPeripherals(withServices: nil)
        SendBleMsg?.onBLEReceiveMsg(msgId: .scanning)
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
    // Discover Pod Characterestics. Subscribe for Notifications
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
                peripheral.setNotifyValue(true, for: characteristic)
                break
            case podIDUUID     :
                podIdCharacteristic = characteristic
                break
            default:
                break
            }
        }
    }
    // Subscribed to notifiaction. Confirm connection
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
//        if let error = error {
//            // Handle error
//            return
//        }
        if characteristic == notifyCharacteristic {
            SendBleMsg?.onBLEReceiveMsg(msgId: .connected)
        }
    }
    
    // Request write to BLE characteristic
    func writeOpData(value: Data) {
        podSenser?.writeValue(value, for: opDataCharacteristic, type: .withResponse)
     }
    // Confirm write complete
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
//        if let error = error {
//            // Handle error
//            return
//        }
        SendBleMsg?.onBLEReceiveMsg(msgId: sentMsgId)
    }
    // Request read BLE characteristic
    func readValue(characteristic: CBCharacteristic) {
        podSenser?.readValue(for: characteristic)
    }
    // Received read characteristic data
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
//        if let error = error {
//            // Handle error
//            return
//        }
        guard let value = characteristic.value else {
            return
        }
        SendBleMsg?.onBLEReceiveData(rowData: value)
    }
    func cancelConnection ( ) {
        guard let periphiral = podSenser else {
            return
        }
        centralManager.cancelPeripheralConnection(periphiral)
    }
}
