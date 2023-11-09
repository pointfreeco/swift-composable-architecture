//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import Foundation

internal struct _ManagedCriticalState<State> {
  private let lock = NSLock()
  final private class LockedBuffer: ManagedBuffer<State, UnsafeRawPointer> { }

  private let buffer: ManagedBuffer<State, UnsafeRawPointer>

  internal init(_ buffer: ManagedBuffer<State, UnsafeRawPointer>) {
    self.buffer = buffer
  }

  internal init(_ initial: State) {
    let roundedSize = (MemoryLayout<UnsafeRawPointer>.size - 1) / MemoryLayout<UnsafeRawPointer>.size
    self.init(LockedBuffer.create(minimumCapacity: Swift.max(roundedSize, 1)) { buffer in
      return initial
    })
  }

  internal func withCriticalRegion<R>(
    _ critical: (inout State) throws -> R
  ) rethrows -> R {
    try buffer.withUnsafeMutablePointers { header, lock in
      self.lock.lock()
      defer {
        self.lock.unlock()
      }
      return try critical(&header.pointee)
    }
  }
}

extension _ManagedCriticalState: @unchecked Sendable where State: Sendable { }

extension _ManagedCriticalState: Identifiable {
  internal var id: ObjectIdentifier {
    ObjectIdentifier(buffer)
  }
}
