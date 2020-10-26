//
//  Service.swift
//  ComposableCoreBluetooth
//
//  Created by Philipp Gabriel on 15.07.20.
//  Copyright © 2020 Philipp Gabriel. All rights reserved.
//

import Foundation
import CoreBluetooth

public struct Service: Equatable {

    let rawValue: CBService?
    public let identifier: CBUUID
    public let isPrimary: Bool
    public let characteristics: [Characteristic]?
    public let includedServices: [Service]?
    
    init(from service: CBService) {
        rawValue = service
        identifier = service.uuid
        isPrimary = service.isPrimary
        characteristics = service.characteristics?.map(Characteristic.init)
        includedServices = service.includedServices?.map(Service.init)
    }
    
    init(
        identifier: CBUUID,
        isPrimary: Bool,
        characteristics: [Characteristic]?,
        includedServices: [Service]?
    ) {
        rawValue = nil
        self.identifier = identifier
        self.isPrimary = isPrimary
        self.characteristics = characteristics
        self.includedServices = includedServices
    }
}
