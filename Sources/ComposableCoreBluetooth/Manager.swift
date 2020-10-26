//
//  Manager.swift
//  ComposableCoreBluetooth
//
//  Created by Philipp Gabriel on 15.07.20.
//  Copyright © 2020 Philipp Gabriel. All rights reserved.
//

import Foundation
import CoreBluetooth
import ComposableArchitecture

public struct BluetoothManager {
    
    var create: (AnyHashable, DispatchQueue?, InitializationOptions?) -> Effect<Action, Never>
    var destroy: (AnyHashable) -> Effect<Never, Never>
    var connect: (AnyHashable, Peripheral, ConnectionOptions?) -> Effect<Never, Never>
    var cancelConnection: (AnyHashable, Peripheral) -> Effect<Never, Never>
    var retrieveConnectedPeripherals: (AnyHashable, [CBUUID]) -> [Peripheral]
    var retrievePeripherals: (AnyHashable, [UUID]) -> [Peripheral]
    var scanForPeripherals: (AnyHashable, [CBUUID]?, ScanOptions?) -> Effect<Never, Never>
    var stopScan: (AnyHashable) -> Effect<Never, Never>
    var isScanning: (AnyHashable) -> Bool
    var supports: (CBCentralManager.Feature) -> Bool
    var registerForConnectionEvents: (AnyHashable, ConnectionEventOptions?) -> Effect<Never, Never>

    public init(
        create: @escaping (AnyHashable, DispatchQueue?, InitializationOptions?) -> Effect<Action, Never>,
        destroy: @escaping (AnyHashable) -> Effect<Never, Never>,
        connect: @escaping (AnyHashable, Peripheral, ConnectionOptions?) -> Effect<Never, Never>,
        cancelConnection: @escaping (AnyHashable, Peripheral) -> Effect<Never, Never>,
        retrieveConnectedPeripherals: @escaping (AnyHashable, [CBUUID]) -> [Peripheral],
        retrievePeripherals: @escaping (AnyHashable, [UUID]) -> [Peripheral],
        scanForPeripherals: @escaping (AnyHashable, [CBUUID]?, ScanOptions?) -> Effect<Never, Never>,
        stopScan: @escaping (AnyHashable) -> Effect<Never, Never>,
        isScanning: @escaping (AnyHashable) -> Bool,
        registerForConnectionEvents: @escaping (AnyHashable, ConnectionEventOptions?) -> Effect<Never, Never>,
        supports: @escaping (CBCentralManager.Feature) -> Bool
    ) {
        self.create = create
        self.destroy = destroy
        self.connect = connect
        self.cancelConnection = cancelConnection
        self.retrieveConnectedPeripherals = retrieveConnectedPeripherals
        self.retrievePeripherals = retrievePeripherals
        self.scanForPeripherals = scanForPeripherals
        self.stopScan = stopScan
        self.isScanning = isScanning
        self.supports = supports
        self.registerForConnectionEvents = registerForConnectionEvents
    }
}

extension BluetoothManager {
    public func create(id: AnyHashable, queue: DispatchQueue? = nil, options: InitializationOptions? = nil) -> Effect<Action, Never> {
        create(id, queue, options)
    }
    
    public func destroy(id: AnyHashable) -> Effect<Never, Never> {
        destroy(id)
    }
    
    public func connect(id: AnyHashable, to peripheral: Peripheral, options: ConnectionOptions? = nil) -> Effect<Never, Never> {
        connect(id, peripheral, options)
    }
    
    public func cancelConnection(id: AnyHashable, with peripheral: Peripheral) -> Effect<Never, Never> {
        cancelConnection(id, peripheral)
    }
    
    public func retrieveConnectedPeripherals(id: AnyHashable, services: [CBUUID]) -> [Peripheral] {
        retrieveConnectedPeripherals(id, services)
    }
    
    public func retrievePeripherals(id: AnyHashable, identifiers: [UUID]) -> [Peripheral] {
        retrievePeripherals(id, identifiers)
    }
    
    public func scanForPeripherals(id: AnyHashable, services: [CBUUID]? = nil, options: ScanOptions? = nil) -> Effect<Never, Never> {
        scanForPeripherals(id, services, options)
    }
    
    public func stopScan(id: AnyHashable) -> Effect<Never, Never> {
        stopScan(id)
    }
    
    public func isScanning(id: AnyHashable) -> Bool {
        isScanning(id)
    }
    
    public func supports(_ feature: CBCentralManager.Feature) -> Bool {
        supports(feature)
    }
    
    public func registerForConnectionEvents(id: AnyHashable, options: ConnectionEventOptions? = nil) -> Effect<Never, Never> {
        registerForConnectionEvents(id, options)
    }
}

extension BluetoothManager {
    
    public struct InitializationOptions {
        
        let showPowerAlert: Bool?
        let restoreIdentifier: String?
        
        public init(showPowerAlert: Bool? = nil, restoreIdentifier: String? = nil) {
            self.showPowerAlert = showPowerAlert
            self.restoreIdentifier = restoreIdentifier
        }
        
        func toDictionary() -> [String: Any] {
            var dictionary = [String: Any]()
            
            if let showPowerAlert = showPowerAlert {
                dictionary[CBCentralManagerOptionShowPowerAlertKey] = NSNumber(booleanLiteral: showPowerAlert)
            }
            
            if let restoreIdentifier = restoreIdentifier {
                dictionary[CBCentralManagerOptionRestoreIdentifierKey] = restoreIdentifier as NSString
            }
            
            return dictionary
        }
    }
    
    public struct ConnectionOptions {
        
        let notifyOnConnection: Bool?
        let notifyOnDisconnection: Bool?
        let notifyOnNotification: Bool?
        let enableTransportBridging: Bool?
        let requiredANCS: Bool?
        let startDelay: NSNumber?
        
        public init(
            notifyOnConnection: Bool? = nil,
            notifyOnDisconnection: Bool? = nil,
            notifyOnNotification: Bool? = nil,
            enableTransportBridging: Bool? = nil,
            requiredANCS: Bool? = nil,
            startDelay: NSNumber? = nil
        ) {
            self.notifyOnConnection = notifyOnConnection
            self.notifyOnDisconnection = notifyOnDisconnection
            self.notifyOnNotification = notifyOnNotification
            self.enableTransportBridging = enableTransportBridging
            self.requiredANCS = requiredANCS
            self.startDelay = startDelay
        }
        
        func toDictionary() -> [String: Any] {
            var dictionary = [String: Any]()
            
            if let notifyOnConnection = notifyOnConnection {
                dictionary[CBConnectPeripheralOptionNotifyOnConnectionKey] = NSNumber(booleanLiteral: notifyOnConnection)
            }
            
            if let notifyOnDisconnection = notifyOnDisconnection {
                dictionary[CBConnectPeripheralOptionNotifyOnDisconnectionKey] = NSNumber(booleanLiteral: notifyOnDisconnection)
            }
            
            if let notifyOnNotification = notifyOnNotification {
                dictionary[CBConnectPeripheralOptionNotifyOnNotificationKey] = NSNumber(booleanLiteral: notifyOnNotification)
            }
            
            if let enableTransportBridging = enableTransportBridging {
                dictionary[CBConnectPeripheralOptionEnableTransportBridgingKey] = NSNumber(booleanLiteral: enableTransportBridging)
            }
            
            if let requiredANCS = requiredANCS {
                dictionary[CBConnectPeripheralOptionRequiresANCS] = NSNumber(booleanLiteral: requiredANCS)
            }
            
            if let startDelay = startDelay {
                dictionary[CBConnectPeripheralOptionStartDelayKey] = startDelay
            }
            
            return dictionary
        }
    }
    
    public struct ScanOptions: Equatable {
        
        let allowDuplicates: Bool?
        let solicitedServiceUUIDs: [CBUUID]?
        
        public init(allowDuplicates: Bool? = nil, solicitedServiceUUIDs: [CBUUID]? = nil) {
            self.allowDuplicates = allowDuplicates
            self.solicitedServiceUUIDs = solicitedServiceUUIDs
        }
        
        init(from dictionary: [String: Any]?) {
            allowDuplicates = (dictionary?[CBCentralManagerScanOptionAllowDuplicatesKey] as? NSNumber)?.boolValue
            solicitedServiceUUIDs = dictionary?[CBCentralManagerScanOptionSolicitedServiceUUIDsKey] as? [CBUUID]
        }
        
        func toDictionary() -> [String: Any] {
            
            var dictionary = [String: Any]()
            
            if let allowDuplicates = allowDuplicates {
                dictionary[CBCentralManagerScanOptionAllowDuplicatesKey] = NSNumber(booleanLiteral: allowDuplicates)
            }
            
            if let solicitedServiceUUIDs = solicitedServiceUUIDs {
                dictionary[CBCentralManagerScanOptionSolicitedServiceUUIDsKey] = solicitedServiceUUIDs as NSArray
            }
            
            return dictionary
        }
    }
    
    public struct ConnectionEventOptions {
        
        let peripheralUUIDs: [UUID]?
        let serviceUUIDs: [CBUUID]?
        
        public init(peripheralUUIDs: [UUID]? = nil, serviceUUIDs: [CBUUID]? = nil) {
            self.peripheralUUIDs = peripheralUUIDs
            self.serviceUUIDs = serviceUUIDs
        }
        
        func toDictionary() -> [CBConnectionEventMatchingOption : Any] {
            var dictionary = [CBConnectionEventMatchingOption: Any]()

            if let peripheralUUIDs = peripheralUUIDs {
                dictionary[.peripheralUUIDs] = peripheralUUIDs as NSArray
            }
            
            if let serviceUUIDs = serviceUUIDs {
                dictionary[.serviceUUIDs] = serviceUUIDs as NSArray
            }
            
            return dictionary
        }
    }
}

extension BluetoothManager {
    
    public enum Action: Equatable {
        case didConnect(Peripheral)
        case didDisconnect(Peripheral, CBError?)
        case didFailToConnect(Peripheral, CBError?)
        case connectionEventDidOccur(CBConnectionEvent, Peripheral)
        case didDiscover(Peripheral, AdvertismentData, NSNumber)
        case willRestore(RestorationOptions)
        case didUpdateANCSAuthorization(Peripheral)
        case didUpdateState(CBManagerState)
        
        case peripheral(UUID, Peripheral.Action)
    }
}

extension BluetoothManager.Action {
    public struct AdvertismentData: Equatable {
        
        public let localName: String?
        public let manufacturerData: Data?
        public let serviceData: [CBUUID: Data]?
        public let serviceUUIDs: [CBUUID]?
        public let overflowServiceUUIDs: [CBUUID]?
        public let solicitedServiceUUIDs: [CBUUID]?
        public let txPowerLevel: NSNumber?
        public let isConnectable: Bool?
        
        init(from dictionary: [String: Any]) {
            localName = dictionary[CBAdvertisementDataLocalNameKey] as? String
            manufacturerData = dictionary[CBAdvertisementDataManufacturerDataKey] as? Data
            txPowerLevel = dictionary[CBAdvertisementDataTxPowerLevelKey] as? NSNumber
            isConnectable = (dictionary[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue
            serviceData = dictionary[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data]
            serviceUUIDs = dictionary[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
            overflowServiceUUIDs = dictionary[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID]
            solicitedServiceUUIDs = dictionary[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID]
        }
    }
    
    public struct RestorationOptions: Equatable {
        
        public let peripherals: [Peripheral]?
        public let scannedServices: [CBUUID]?
        public let scanOptions: BluetoothManager.ScanOptions?
        
        init(from dictionary: [String: Any], subscriber: Effect<BluetoothManager.Action, Never>.Subscriber) {
            peripherals = (dictionary[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral])?.map { peripheral in
                Peripheral.live(from: peripheral, subscriber: subscriber)
            }
            
            scannedServices = dictionary[CBCentralManagerRestoredStateScanServicesKey] as? [CBUUID]
            scanOptions = .init(from: dictionary[CBCentralManagerRestoredStateScanOptionsKey] as? [String: Any])
        }
    }
}
