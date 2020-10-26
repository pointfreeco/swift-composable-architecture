//
//  Characteristic.swift
//  ComposableCoreBluetooth
//
//  Created by Philipp Gabriel on 15.07.20.
//  Copyright © 2020 Philipp Gabriel. All rights reserved.
//

import Foundation
import CoreBluetooth

public struct Characteristic: Equatable {
    
    let rawValue: CBCharacteristic?
    public let identifier: CBUUID
    public let value: Data?
    public let isNotifying: Bool
    public let descriptors: [Descriptor]?
    
    init(from characteristic: CBCharacteristic) {
        rawValue = characteristic
        identifier = characteristic.uuid
        value = characteristic.value
        isNotifying = characteristic.isNotifying
        descriptors = characteristic.descriptors?.map(Descriptor.init)
    }
    
    init(
        identifier: CBUUID,
        value: Data?,
        isNotifying: Bool,
        descriptors: [Descriptor]?
    ) {
        rawValue = nil
        self.identifier = identifier
        self.value = value
        self.isNotifying = isNotifying
        self.descriptors = descriptors
    }
}
