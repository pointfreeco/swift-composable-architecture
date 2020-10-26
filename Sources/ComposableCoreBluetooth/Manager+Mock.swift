//
//  Manager+Mock.swift
//  ComposableCoreBluetooth
//
//  Created by Philipp Gabriel on 15.07.20.
//  Copyright © 2020 Philipp Gabriel. All rights reserved.
//

import Foundation
import CoreBluetooth
import ComposableArchitecture

public func _unimplemented(_ function: StaticString, file: StaticString = #file, line: UInt = #line) -> Never {
    fatalError(
        """
        `\(function)` was called but is not implemented. Be sure to provide an implementation for this endpoint when creating the mock.
        """,
        file: file,
        line: line
    )
}

extension BluetoothManager {
    
    @available(macOS, unavailable)
    public static func mock(
        create: @escaping (AnyHashable, DispatchQueue?, InitializationOptions?) -> Effect<Action, Never> = { _, _, _ in
            _unimplemented("create")
        },
        destroy: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
            _unimplemented("destroy")
        },
        connect: @escaping (AnyHashable, Peripheral, ConnectionOptions?) -> Effect<Never, Never> = { _, _, _ in
            _unimplemented("connect")
        },
        cancelConnection: @escaping (AnyHashable, Peripheral) -> Effect<Never, Never> = { _, _ in
            _unimplemented("cancelConnection")
        },
        retrieveConnectedPeripherals: @escaping (AnyHashable, [CBUUID]) -> [Peripheral] = { _, _ in
            _unimplemented("retrieveConnectedPeripherals")
        },
        retrievePeripherals: @escaping (AnyHashable, [UUID]) -> [Peripheral] = { _, _ in
            _unimplemented("retrievePeripherals")
        },
        scanForPeripherals: @escaping (AnyHashable, [CBUUID]?, ScanOptions?) -> Effect<Never, Never> = { _, _, _ in
            _unimplemented("scanForPeripherals")
        },
        stopScan: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
            _unimplemented("stopScan")
        },
        isScanning: @escaping (AnyHashable) -> Bool = { _ in
            _unimplemented("isScanning")
        },
        registerForConnectionEvents: @escaping (AnyHashable, ConnectionEventOptions?) -> Effect<Never, Never> = { _, _ in
            _unimplemented("registerForConnectionEvents")
        },
        supports: @escaping (CBCentralManager.Feature) -> Bool = { _ in
            _unimplemented("supports")
        }
    ) -> Self {
        Self(
            create: create,
            destroy: destroy,
            connect: connect,
            cancelConnection: cancelConnection,
            retrieveConnectedPeripherals: retrieveConnectedPeripherals,
            retrievePeripherals: retrievePeripherals,
            scanForPeripherals: scanForPeripherals,
            stopScan: stopScan,
            isScanning: isScanning,
            registerForConnectionEvents: registerForConnectionEvents,
            supports: supports
        )
    }
    
    public static func mock(
        create: @escaping (AnyHashable, DispatchQueue?, InitializationOptions?) -> Effect<Action, Never> = { _, _, _ in
            _unimplemented("create")
        },
        destroy: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
            _unimplemented("destroy")
        },
        connect: @escaping (AnyHashable, Peripheral, ConnectionOptions?) -> Effect<Never, Never> = { _, _, _ in
            _unimplemented("connect")
        },
        cancelConnection: @escaping (AnyHashable, Peripheral) -> Effect<Never, Never> = { _, _ in
            _unimplemented("cancelConnection")
        },
        retrieveConnectedPeripherals: @escaping (AnyHashable, [CBUUID]) -> [Peripheral] = { _, _ in
            _unimplemented("retrieveConnectedPeripherals")
        },
        retrievePeripherals: @escaping (AnyHashable, [UUID]) -> [Peripheral] = { _, _ in
            _unimplemented("retrievePeripherals")
        },
        scanForPeripherals: @escaping (AnyHashable, [CBUUID]?, ScanOptions?) -> Effect<Never, Never> = { _, _, _ in
            _unimplemented("scanForPeripherals")
        },
        stopScan: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
            _unimplemented("stopScan")
        },
        isScanning: @escaping (AnyHashable) -> Bool = { _ in
            _unimplemented("isScanning")
        }
    ) -> Self {
        Self(
            create: create,
            destroy: destroy,
            connect: connect,
            cancelConnection: cancelConnection,
            retrieveConnectedPeripherals: retrieveConnectedPeripherals,
            retrievePeripherals: retrievePeripherals,
            scanForPeripherals: scanForPeripherals,
            stopScan: stopScan,
            isScanning: isScanning
        )
    }
}
