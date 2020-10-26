//
//  Peripheral.swift
//  ComposableCoreBluetooth
//
//  Created by Philipp Gabriel on 15.07.20.
//  Copyright © 2020 Philipp Gabriel. All rights reserved.
//

import CoreBluetooth
import ComposableArchitecture
import Combine

private func couldNotFindRawServiceValue() {
    assertionFailure(
        """
        The supplied service did not have a raw value. This is considered a programmer error. \
        You should use the Service.init(from:) initializer.
        """
    )
}

private func couldNotFindRawCharacteristicValue() {
    assertionFailure(
        """
        The supplied characteristic did not have a raw value. This is considered a programmer error. \
        You should use the Characteristic.init(from:) initializer.
        """
    )
}

private func couldNotFindRawDescriptorValue() {
    assertionFailure(
        """
        The supplied descriptor did not have a raw value. This is considered a programmer error. \
        You should use the Descriptor.init(from:) initializer.
        """
    )
}

extension Peripheral {
    
    public static func live(from peripheral: CBPeripheral, subscriber: Effect<BluetoothManager.Action, Never>.Subscriber) -> Self {
        
        Self(
            rawValue: peripheral,
            delegate: Delegate(subscriber),
            identifier: { peripheral.identifier },
            name: { peripheral.name },
            services: { peripheral.services?.map(Service.init) },
            discoverServices: { ids in
                .fireAndForget { peripheral.discoverServices(ids) }
            },
            discoverIncludedServices: { ids, service in
                
                guard let rawService = service.rawValue else {
                    couldNotFindRawServiceValue()
                    return .none
                }
                
                return .fireAndForget { peripheral.discoverIncludedServices(ids, for: rawService) }
            },
            discoverCharacteristics: { ids, service in
                
                guard let rawService = service.rawValue else {
                    couldNotFindRawServiceValue()
                    return .none
                }
                
                return .fireAndForget { peripheral.discoverCharacteristics(ids, for: rawService) }
            },
            discoverDescriptors: { characteristic in
                
                guard let rawCharacteristic = characteristic.rawValue else {
                    couldNotFindRawCharacteristicValue()
                    return .none
                }
                
                return .fireAndForget { peripheral.discoverDescriptors(for: rawCharacteristic) }
            },
            readCharacteristicValue: { characteristic in
                
                guard let rawCharacteristic = characteristic.rawValue else {
                    couldNotFindRawCharacteristicValue()
                    return .none
                }
                
                return .fireAndForget { peripheral.readValue(for: rawCharacteristic) }
            },
            readDescriptorValue: { descriptor in
                
                guard let rawDescriptor = descriptor.rawValue else {
                    couldNotFindRawDescriptorValue()
                    return .none
                }
                
                return .fireAndForget { peripheral.readValue(for: rawDescriptor) }
            },
            writeCharacteristicValue: { data, characteristic, writeType in
                
                guard let rawCharacteristic = characteristic.rawValue else {
                    couldNotFindRawCharacteristicValue()
                    return .none
                }
                
                return .fireAndForget { peripheral.writeValue(data, for: rawCharacteristic, type: writeType) }
            },
            writeDescriptorValue: { data, descriptor in
                
                guard let rawDescriptor = descriptor.rawValue else {
                    couldNotFindRawDescriptorValue()
                    return .none
                }
                
                return .fireAndForget { peripheral.writeValue(data, for: rawDescriptor) }
            },
            maximumWriteValueLength: peripheral.maximumWriteValueLength,
            setNotifyValue: { value, characteristic in
                
                guard let rawCharacteristic = characteristic.rawValue else {
                    couldNotFindRawCharacteristicValue()
                    return .none
                }
                
                return .fireAndForget { peripheral.setNotifyValue(value, for: rawCharacteristic) }
            },
            state: { peripheral.state },
            canSendWriteWithoutResponse: { peripheral.canSendWriteWithoutResponse },
            readRSSI: {
                .fireAndForget { peripheral.readRSSI() }
            },
            openL2CAPChannel: { psm in
                .fireAndForget { peripheral.openL2CAPChannel(psm) }
            },
            ancsAuthorized: { peripheral.ancsAuthorized }
        )
    }
    
    class Delegate: NSObject, CBPeripheralDelegate {
        let subscriber: Effect<BluetoothManager.Action, Never>.Subscriber
        
        init(_ subscriber: Effect<BluetoothManager.Action, Never>.Subscriber) {
            self.subscriber = subscriber
        }
        
        func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            subscriber.send(
                .peripheral(peripheral.identifier, .didDiscoverServices(peripheral.services?.map(Service.init(from:)) ?? [], error as? CBError))
            )
        }
        
        func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
            subscriber.send(
                .peripheral(peripheral.identifier, .didDiscoverIncludedServices(Service(from: service), error as? CBError))
            )
        }
        
        func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
            subscriber.send(
                .peripheral(peripheral.identifier, .didDiscoverCharacteristics(Service(from: service), error as? CBError))
            )
        }
        
        func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
            subscriber.send(
                .peripheral(peripheral.identifier, .didDiscoverDescriptors(Characteristic(from: characteristic), error as? CBError))
            )
        }
        
        func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            subscriber.send(
                .peripheral(peripheral.identifier, .didUpdateCharacteristicValue(Characteristic(from: characteristic), error as? CBError))
            )
        }
        
        func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
            subscriber.send(
                .peripheral(peripheral.identifier, .didUpdateDescriptorValue(Descriptor(from: descriptor), error as? CBError))
            )
        }
        
        func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
            subscriber.send(
                .peripheral(peripheral.identifier, .didWriteCharacteristicValue(Characteristic(from: characteristic), error as? CBError))
            )
        }
        
        func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
            subscriber.send(
                .peripheral(peripheral.identifier, .didWriteDescriptorValue(Descriptor(from: descriptor), error as? CBError))
            )
        }
        
        func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
            subscriber.send(
                .peripheral(peripheral.identifier, .isReadyToSendWriteWithoutResponse)
            )
        }
        
        func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
            subscriber.send(
                .peripheral(peripheral.identifier, .didUpdateNotificationState(Characteristic(from: characteristic), error as? CBError))
            )
        }
        
        func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
            subscriber.send(
                .peripheral(peripheral.identifier, .didReadRSSI(RSSI, error as? CBError))
            )
        }
        
        func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
            subscriber.send(
                .peripheral(peripheral.identifier, .didUpdateName(peripheral.name))
            )
        }
        
        func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
            subscriber.send(
                .peripheral(peripheral.identifier, .didModifyServices(invalidatedServices.map(Service.init)))
            )
        }
        
        func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
            subscriber.send(
                .peripheral(peripheral.identifier, .didOpenL2CAPChannel(channel, error as? CBError))
            )
        }
    }
}
