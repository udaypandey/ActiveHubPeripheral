//
//  DMActiveHubDevice.swift
//  ActiveHubPeripheral
//
//  Created by Uday Pandey on 01/06/2017.
//  Copyright © 2017 Centrica Connected Home. All rights reserved.
//

import Foundation
import CoreBluetooth

class DebugLogger {
    static func info(_ value: String) {
        print(value)
    }
}

enum ActiveHubUUID: String {
    case service                 = "64B777E4-1F94-4388-B098-665DC9F26881"
    
    // Receive data from Central, Central writes into this
    case receiveCharacteristic   = "8CED9D9F-9EAD-4CE8-964C-0EAC13467236"
    
    // Send data to Central, Central cant write, so read
    case transmitCharacteristic  = "C9D7271A-1B8C-4F17-9756-F7EB36B18A2B"
    
    var uuid: CBUUID {
        return CBUUID(string: rawValue)
    }
}

class DMActiveHubDevice: NSObject, CBPeripheralManagerDelegate {
    var peripheralManger: CBPeripheralManager!
    
    var receiveCharacteristc: CBMutableCharacteristic!
    var transmitCharacteristic: CBMutableCharacteristic!
    
    func startAdvertising() {
        var advertisement: [String : Any] = [:]
        
        advertisement[CBAdvertisementDataServiceUUIDsKey] = [ActiveHubUUID.service.uuid]
        advertisement[CBAdvertisementDataLocalNameKey] = "Hive Active Hub"

        DebugLogger.info("startAdvertising: \(advertisement)")

        peripheralManger.startAdvertising(advertisement)
    }
    
    func stopAdvertising() {
        peripheralManger.stopAdvertising()
    }

    override init() {
        super.init()
        
        peripheralManger = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    fileprivate func addService() {
        
        var properties: CBCharacteristicProperties = [.notify, .read]
        let permissions: CBAttributePermissions = [.readable, .writeable]

        transmitCharacteristic = CBMutableCharacteristic(type: ActiveHubUUID.transmitCharacteristic.uuid,
                                                         properties: properties,
                                                         value: nil,
                                                         permissions: permissions)

        properties = [.write]
        receiveCharacteristc = CBMutableCharacteristic(type: ActiveHubUUID.receiveCharacteristic.uuid,
                                                       properties: properties,
                                                       value: nil,
                                                       permissions: permissions)

        
        let service = CBMutableService(type: ActiveHubUUID.service.uuid, primary: true)
        service.characteristics = [receiveCharacteristc, transmitCharacteristic]
        
        peripheralManger.add(service)
    }
}


extension DMActiveHubDevice {
    enum MessageType: String {
        case btAppStatus                = "BT_APP_STATUS"
        
        case wifiStatusRequest          = "WIFI_INTERFACE_STATUS_REQUEST"
        case wifiStatusResponse         = "WIFI_INTERFACE_STATUS_RESPONSE"
        
        case wifiAvailableRequest       = "WIFI_INTERFACES_AVAILABLE_REQUEST"
        case wifiAvailableResponse      = "WIFI_INTERFACES_AVAILABLE_RESPONSE"
        
        case setActiveSSIDRequest       = "SET_ACTIVE_SSID_REQUEST"
        case setActiveSSIDResponse      = "SET_ACTIVE_SSID_RESPONSE"
        
        func response() -> Data? {
            var dict: [String: Any] = [:]
            switch self {
            case .btAppStatus:
                dict["messageType"] = self.rawValue
                
                dict["appState"] = "INITIALISING"
                dict["errorCode"] = "NO_ERROR"
                
            case .wifiStatusRequest:
                dict["messageType"] = MessageType.wifiStatusResponse.rawValue
                
                dict["adapterName"] = "Active Hub Device"
                dict["adapterMacAddress"] = "aa:bb:cc:dd"
                dict["interfaceUp"] = true
                dict["ipAddress"] = "10.1.1.2"
                dict["statusDump"] = "BK Example"
                dict["currentSSID"] = "BGCH"
                dict["currentSecurityType"] = "WEP"
                dict["hasInternet"] = false
                
            case .wifiAvailableRequest:
                dict["messageType"] = MessageType.wifiAvailableResponse.rawValue
                
                dict["availableSSIDs"] = [
                    ["pskType": "", "ssid": "BGCH",  "psk": "", "signalLevel": 100, "enabled": true],
                    ["pskType": "", "ssid": "BGCH 1","psk": "", "signalLevel": 80, "enabled": true],
                    ["pskType": "", "ssid": "BGCH 1","psk": "", "signalLevel": 80, "enabled": true]
                ]
                
            case .setActiveSSIDRequest:
                dict["messageType"] = MessageType.wifiAvailableResponse.rawValue
                
                dict["status"] = "SUCCESS"
                dict["statusMessage"] = "ALL GOOD"
                
            default:
                return nil
            }
            
            guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else { return nil }
            return data.dataAfterAppendingHeader
        }
    }
    
    func handleIncomingRequest(_ peripheral: CBPeripheralManager, request: CBATTRequest) {
        // Check its on the right characteristic
        // Check we can parse the response
        // Reply with the right default response
        if request.characteristic.uuid == ActiveHubUUID.receiveCharacteristic.uuid {
            if let data = request.value {
                let jsonData = data.dataAfterStrippingHeader
                
                guard let jsonRequest = try? JSONSerialization.jsonObject(with: jsonData) as! [String:String] else {
                    print("Received data can't be parsed")
                    return
                }
                
                if let messageTypeString = jsonRequest["messageType"],
                    let messageType = MessageType(rawValue: messageTypeString),
                    let defaultResponse = messageType.response() {
                    
                    // Send response back on transmit characteristic
                    peripheral.updateValue(defaultResponse, for: transmitCharacteristic, onSubscribedCentrals: nil)
                }
            }
        }
    }
}

extension DMActiveHubDevice {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        DebugLogger.info("peripheralManagerDidUpdateState: ")
        
        switch peripheral.state {
        case .poweredOn:
            addService()
        default:
            DebugLogger.info("peripheralManagerDidUpdateState: Device not ready")
            break
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        DebugLogger.info("peripheralManagerDidStartAdvertising: ")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        DebugLogger.info("didAddService: ")
        startAdvertising()
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        DebugLogger.info("didSubscribeToCharacteristic: ")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        DebugLogger.info("didUnsubscribeFromCharacteristic: ")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        DebugLogger.info("didReceiveReadRequest: ")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        DebugLogger.info("didReceiveWriteRequests: ")
        
        for request in requests {
            handleIncomingRequest(peripheral, request: request)
            peripheral.respond(to: request, withResult: .success)
        }
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        DebugLogger.info("peripheralManagerIsReadyToUpdateSubscribers: ")
    }
}


extension Data {
    var dataAfterAppendingHeader: Data {
        let byte0:UInt8 = 0xaa
        let byte1:UInt8 = 0x55
        let byte2:UInt8 = 0xaa
        let byte3:UInt8 = msb
        let byte4:UInt8 = lsb
        
        var headerData = Data(bytes: [byte0, byte1, byte2, byte3, byte4])
        headerData.append(self)
        return headerData
    }
    
    var dataAfterStrippingHeader: Data {
        return subdata(in: 5..<self.count)
    }

    private var msb: UInt8 {
        // Most significant byte Assuming count of message is less than 2^16
        let length = UInt16(self.count)
        let msb = UInt8((length >> 8) & 0xff)
        return msb
    }
    
    private var lsb: UInt8 {
        // Least significant byte
        let length = UInt16(self.count)
        let lsb = UInt8(length & 0xff)
        return lsb
    }
}
