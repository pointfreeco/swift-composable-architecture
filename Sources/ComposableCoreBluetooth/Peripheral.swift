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
    
    public internal(set) var identifier: () -> UUID = {
        _unimplemented("identifier")
    }
    
    public internal(set) var name: () -> String? = {
        _unimplemented("name")
    }
    
    public internal(set) var services: () -> [Service]? = {
        _unimplemented("services")
    }
    
    public internal(set) var state: () -> CBPeripheralState = {
        _unimplemented("state")
    }
    
    public internal(set) var canSendWriteWithoutResponse: () -> Bool = {
        _unimplemented("canSendWriteWithoutResponse")
    }
    
    public internal(set) var readRSSI: () -> Effect<Never, Never> = {
        _unimplemented("readRSSI")
    }
    
    var discoverServices: ([CBUUID]?) -> Effect<Never, Never> = { _ in
        _unimplemented("discoverServices")
    }
    
    var discoverIncludedServices: ([CBUUID]?, Service) -> Effect<Never, Never> = { _, _ in
        _unimplemented("discoverIncludedServices")
    }
    
    var discoverCharacteristics: ([CBUUID]?, Service) -> Effect<Never, Never> = { _, _ in
        _unimplemented("discoverCharacteristics")
    }
    
    var discoverDescriptors: (Characteristic) -> Effect<Never, Never> = { _ in
        _unimplemented("discoverDescriptors")
    }
    
    var readCharacteristicValue: (Characteristic) -> Effect<Never, Never> = { _ in
        _unimplemented("readCharacteristicValue")
    }
    
    var readDescriptorValue: (Descriptor) -> Effect<Never, Never> = { _ in
        _unimplemented("readDescriptorValue")
    }
    
    var writeCharacteristicValue: (Data, Characteristic, CBCharacteristicWriteType) -> Effect<Never, Never> = { _, _, _ in
        _unimplemented("writeCharacteristicValue")
    }
    
    var writeDescriptorValue: (Data, Descriptor) -> Effect<Never, Never> = { _, _ in
        _unimplemented("writeDescriptorValue")
    }
    
    var maximumWriteValueLength: (CBCharacteristicWriteType) -> Int = { _ in
        _unimplemented("maximumWriteValueLength")
    }
    
    var setNotifyValue: (Bool, Characteristic) -> Effect<Never, Never> = { _, _ in
        _unimplemented("setNotifyValue")
    }
    
    var openL2CAPChannel: (CBL2CAPPSM) -> Effect<Never, Never> = { _ in
        _unimplemented("openL2CAPChannel")
    }
    
    @available(macOS, unavailable)
    public internal(set) var ancsAuthorized: () -> Bool = {
        _unimplemented("ancsAuthorized")
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
