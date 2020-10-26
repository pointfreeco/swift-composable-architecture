//
//  Peripheral.swift
//  ComposableCoreBluetooth
//
//  Created by Philipp Gabriel on 15.07.20.
//  Copyright © 2020 Philipp Gabriel. All rights reserved.
//

import CoreBluetooth
import ComposableArchitecture

public struct Peripheral {
    
    public var rawValue: CBPeripheral?
    var delegate: CBPeripheralDelegate?
    
    public var identifier: () -> UUID
    public var name: () -> String?
    public var services: () -> [Service]?
    public var state: () -> CBPeripheralState
    public var canSendWriteWithoutResponse: () -> Bool
    public var readRSSI: () -> Effect<Never, Never>
    public var ancsAuthorized: () -> Bool
    var discoverServices: ([CBUUID]?) -> Effect<Never, Never>
    var discoverIncludedServices: ([CBUUID]?, Service) -> Effect<Never, Never>
    var discoverCharacteristics: ([CBUUID]?, Service) -> Effect<Never, Never>
    var discoverDescriptors: (Characteristic) -> Effect<Never, Never>
    var readCharacteristicValue: (Characteristic) -> Effect<Never, Never>
    var readDescriptorValue: (Descriptor) -> Effect<Never, Never>
    var writeCharacteristicValue: (Data, Characteristic, CBCharacteristicWriteType) -> Effect<Never, Never>
    var writeDescriptorValue: (Data, Descriptor) -> Effect<Never, Never>
    var maximumWriteValueLength: (CBCharacteristicWriteType) -> Int
    var setNotifyValue: (Bool, Characteristic) -> Effect<Never, Never>
    var openL2CAPChannel: (CBL2CAPPSM) -> Effect<Never, Never>
    
    public init(
        rawValue: CBPeripheral?,
        delegate: CBPeripheralDelegate?,
        identifier: @escaping () -> UUID,
        name: @escaping () -> String?,
        services: @escaping () -> [Service]?,
        discoverServices: @escaping ([CBUUID]?) -> Effect<Never, Never>,
        discoverIncludedServices: @escaping ([CBUUID]?, Service) -> Effect<Never, Never>,
        discoverCharacteristics: @escaping ([CBUUID]?, Service) -> Effect<Never, Never>,
        discoverDescriptors: @escaping (Characteristic) -> Effect<Never, Never>,
        readCharacteristicValue: @escaping (Characteristic) -> Effect<Never, Never>,
        readDescriptorValue: @escaping (Descriptor) -> Effect<Never, Never>,
        writeCharacteristicValue: @escaping (Data, Characteristic, CBCharacteristicWriteType) -> Effect<Never, Never>,
        writeDescriptorValue: @escaping (Data, Descriptor) -> Effect<Never, Never>,
        maximumWriteValueLength: @escaping (CBCharacteristicWriteType) -> Int,
        setNotifyValue: @escaping (Bool, Characteristic) -> Effect<Never, Never>,
        state: @escaping () -> CBPeripheralState,
        canSendWriteWithoutResponse: @escaping () -> Bool,
        readRSSI: @escaping () -> Effect<Never, Never>,
        openL2CAPChannel: @escaping (CBL2CAPPSM) -> Effect<Never, Never>,
        ancsAuthorized: @escaping () -> Bool
    ) {
        self.rawValue = rawValue
        self.delegate = delegate
        self.rawValue?.delegate = delegate
        self.identifier = identifier
        self.name = name
        self.services = services
        self.discoverServices = discoverServices
        self.discoverIncludedServices = discoverIncludedServices
        self.discoverCharacteristics = discoverCharacteristics
        self.discoverDescriptors = discoverDescriptors
        self.readCharacteristicValue = readCharacteristicValue
        self.readDescriptorValue = readDescriptorValue
        self.writeCharacteristicValue = writeCharacteristicValue
        self.writeDescriptorValue = writeDescriptorValue
        self.maximumWriteValueLength = maximumWriteValueLength
        self.setNotifyValue = setNotifyValue
        self.state = state
        self.canSendWriteWithoutResponse = canSendWriteWithoutResponse
        self.readRSSI = readRSSI
        self.openL2CAPChannel = openL2CAPChannel
        self.ancsAuthorized = ancsAuthorized
    }
}

extension Peripheral: Equatable {
    public static func == (lhs: Peripheral, rhs: Peripheral) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

extension Peripheral {
    public func discoverServices(_ uuids: [CBUUID]? = nil) -> Effect<Never, Never> {
        discoverServices(uuids)
    }
    
    public func discoverIncludedServices(_ uuids: [CBUUID]? = nil, for service: Service) -> Effect<Never, Never> {
        discoverIncludedServices(uuids, service)
    }
    
    public func discoverCharacteristics(_ uuids: [CBUUID]? = nil, for service: Service) -> Effect<Never, Never> {
        discoverCharacteristics(uuids, service)
    }
    
    public func discoverDescriptors(for characteristic: Characteristic) -> Effect<Never, Never> {
        discoverDescriptors(characteristic)
    }
    
    public func readValue(for characteristic: Characteristic) -> Effect<Never, Never> {
        readCharacteristicValue(characteristic)
    }
    
    public func readValue(for descriptor: Descriptor) -> Effect<Never, Never> {
        readDescriptorValue(descriptor)
    }
    
    public func writeValue(_ data: Data, for characteristic: Characteristic, type: CBCharacteristicWriteType) -> Effect<Never, Never> {
        writeCharacteristicValue(data, characteristic, type)
    }
    
    public func writeValue(_ data: Data, for descriptor: Descriptor) -> Effect<Never, Never> {
        writeDescriptorValue(data, descriptor)
    }
    
    public func maximumWriteValueLength(for writeType: CBCharacteristicWriteType) -> Int {
        maximumWriteValueLength(writeType)
    }
    
    public func setNotifyValue(_ enabled: Bool, for characteristic: Characteristic) -> Effect<Never, Never> {
        setNotifyValue(enabled, characteristic)
    }
    
    public func openL2CAPChannel(_ psm: CBL2CAPPSM) -> Effect<Never, Never> {
        openL2CAPChannel(psm)
    }
}

extension Peripheral {
    public enum Action: Equatable {
        case didDiscoverServices([Service], CBError?)
        
        case didDiscoverIncludedServices(Service, CBError?)
        case didDiscoverCharacteristics(Service, CBError?)
        case didDiscoverDescriptors(Characteristic, CBError?)
        
        case didUpdateCharacteristicValue(Characteristic, CBError?)
        case didUpdateDescriptorValue(Descriptor, CBError?)
        
        case didWriteCharacteristicValue(Characteristic, CBError?)
        case didWriteDescriptorValue(Descriptor, CBError?)
        
        case isReadyToSendWriteWithoutResponse
        
        case didUpdateNotificationState(Characteristic, CBError?)
        
        case didReadRSSI(NSNumber, CBError?)
        
        case didUpdateName(String?)
        case didModifyServices([Service])
        
        case didOpenL2CAPChannel(CBL2CAPChannel?, CBError?)
    }
}
