//
//  Peripheral+Mock.swift
//  ComposableCoreBluetooth
//
//  Created by Philipp Gabriel on 15.07.20.
//  Copyright © 2020 Philipp Gabriel. All rights reserved.
//

import CoreBluetooth
import ComposableArchitecture

extension Peripheral {
    
    public static func mock(
        identifier: @escaping () -> UUID = {
            _unimplemented("identifier")
        },
        name: @escaping () -> String? = {
            _unimplemented("name")
        },
        services: @escaping () -> [Service]? = {
            _unimplemented("services")
        },
        discoverServices: @escaping ([CBUUID]?) -> Effect<Never, Never> = { _ in
            _unimplemented("discoverServices")
        },
        discoverIncludedServices: @escaping ([CBUUID]?, Service) -> Effect<Never, Never> = { _, _ in
            _unimplemented("discoverIncludedServices")
        },
        discoverCharacteristics: @escaping ([CBUUID]?, Service) -> Effect<Never, Never> = { _, _ in
            _unimplemented("discoverCharacteristics")
        },
        discoverDescriptors: @escaping (Characteristic) -> Effect<Never, Never> = { _ in
            _unimplemented("discoverDescriptors")
        },
        readCharacteristicValue: @escaping (Characteristic) -> Effect<Never, Never> = { _ in
            _unimplemented("readCharacteristicValue")
        },
        readDescriptorValue: @escaping (Descriptor) -> Effect<Never, Never> = { _ in
            _unimplemented("readDescriptorValue")
        },
        writeCharacteristicValue: @escaping (Data, Characteristic, CBCharacteristicWriteType) -> Effect<Never, Never> = { _, _, _ in
            _unimplemented("writeCharacteristicValue")
        },
        writeDescriptorValue: @escaping (Data, Descriptor) -> Effect<Never, Never> = { _, _ in
            _unimplemented("writeDescriptorValue")
        },
        maximumWriteValueLength: @escaping (CBCharacteristicWriteType) -> Int = { _ in
            _unimplemented("maximumWriteValueLength")
        },
        setNotifyValue: @escaping (Bool, Characteristic) -> Effect<Never, Never> = { _, _ in
            _unimplemented("setNotifyValue")
        },
        state: @escaping () -> CBPeripheralState = {
            _unimplemented("state")
        },
        canSendWriteWithoutResponse: @escaping () -> Bool = {
            _unimplemented("canSendWriteWithoutResponse")
        },
        readRSSI: @escaping () -> Effect<Never, Never> = {
            _unimplemented("readRSSI")
        },
        openL2CAPChannel: @escaping (CBL2CAPPSM) -> Effect<Never, Never> = { _ in
            _unimplemented("openL2CAPChannel")
        },
        ancsAuthorized: @escaping () -> Bool = {
            _unimplemented("ancsAuthorized")
        }
    ) -> Self {
        Self(
            rawValue: nil,
            delegate: nil,
            identifier: identifier,
            name: name,
            services: services,
            discoverServices: discoverServices,
            discoverIncludedServices: discoverIncludedServices,
            discoverCharacteristics: discoverCharacteristics,
            discoverDescriptors: discoverDescriptors,
            readCharacteristicValue: readCharacteristicValue,
            readDescriptorValue: readDescriptorValue,
            writeCharacteristicValue: writeCharacteristicValue,
            writeDescriptorValue: writeDescriptorValue,
            maximumWriteValueLength: maximumWriteValueLength,
            setNotifyValue: setNotifyValue,
            state: state,
            canSendWriteWithoutResponse: canSendWriteWithoutResponse,
            readRSSI: readRSSI,
            openL2CAPChannel: openL2CAPChannel,
            ancsAuthorized: ancsAuthorized
        )
    }
}
