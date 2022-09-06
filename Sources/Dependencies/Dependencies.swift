import CombineSchedulers
import Foundation

public protocol TestDependencyKey {
  associatedtype Value: Sendable
  static var testValue: Value { get }
}
public protocol DependencyKey: TestDependencyKey {
  static var liveValue: Value { get }
}

//extension DependencyKey {
//  public static var testValue: Value { Self.liveValue }
//}

private enum MainRunLoopKey: DependencyKey {
  static let liveValue = AnySchedulerOf<RunLoop>.main
  static let testValue = AnySchedulerOf<RunLoop>.unimplemented
}
extension DependencyValues {
  public var mainRunLoop: AnySchedulerOf<RunLoop> {
    get { self[MainRunLoopKey.self] }
    set { self[MainRunLoopKey.self] = newValue }
  }
  public var mainQueue: AnySchedulerOf<DispatchQueue> {
    get { self[MainQueueKey.self] }
    set { self[MainQueueKey.self] = newValue }
  }
  public var date: @Sendable () -> Date {
    get { self[DateKey.self] }
    set { self[DateKey.self] = newValue }
  }
  public var uuid: @Sendable () -> UUID {
    get { self[UUIDKey.self] }
    set { self[UUIDKey.self] = newValue }
  }
  #if canImport(UIKit)
  public var openSettings: @Sendable () async -> Void {
    get { self[OpenSettingsKey.self] }
    set { self[OpenSettingsKey.self] = newValue }
  }
  #endif
  public var temporaryDirectory: @Sendable () -> URL {
    get { self[TemporaryDirectoryKey.self] }
    set { self[TemporaryDirectoryKey.self] = newValue }
  }
}

private enum MainQueueKey: DependencyKey {
  static let liveValue = AnySchedulerOf<DispatchQueue>.main
  static let testValue = AnySchedulerOf<DispatchQueue>.unimplemented
}

import XCTestDynamicOverlay

private enum DateKey: DependencyKey {
  static let liveValue = { @Sendable in Date() }
  static let testValue: @Sendable () -> Date = XCTUnimplemented(#"@Dependency(\.date)"#, placeholder: Date())
}

private enum UUIDKey: DependencyKey {
  static let liveValue = { @Sendable in UUID() }
  static let testValue: @Sendable () -> UUID = XCTUnimplemented(#"@Dependency(\.uuid)"#, placeholder: UUID())
}

import SwiftUI

#if canImport(UIKit)
private enum OpenSettingsKey: DependencyKey {
  static let liveValue = { @Sendable in
    await MainActor.run {
      UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
  }
  static let testValue: @Sendable () async -> Void = XCTUnimplemented(#"@Dependency(\.openSettings)"#)
}
#endif
private enum TemporaryDirectoryKey: DependencyKey {
  static let liveValue = { @Sendable in URL(fileURLWithPath: NSTemporaryDirectory()) }
  static let testValue: @Sendable () -> URL = XCTUnimplemented(#"@Dependency(\.temporaryDirectory)"#, placeholder: URL(fileURLWithPath: NSTemporaryDirectory()))
}

public struct DependencyValues: Sendable {
  private var storage: [ObjectIdentifier: any Sendable] = [:]
  @TaskLocal public static var current = Self()

  public init() {}

  public subscript<Key: TestDependencyKey>(key: Key.Type) -> Key.Value {
    get {
      guard let dependency = self.storage[ObjectIdentifier(key)] as? Key.Value
      else {
        let isTesting = self.storage[ObjectIdentifier(IsTestingKey.self)] as? Bool ?? false

        guard isTesting
        else {
          return (key as? any DependencyKey.Type)?.liveValue as? Key.Value
          ?? Key.testValue
        }
        return Key.testValue
      }
      return dependency
    }
    set {
      self.storage[ObjectIdentifier(key)] = newValue
    }
  }
}

enum IsTestingKey: DependencyKey {
  static let liveValue = false
  static let testValue = true
}
extension DependencyValues {
  public var isTesting: Bool {
    get { self[IsTestingKey.self] }
    set { self[IsTestingKey.self] = newValue }
  }
}


@propertyWrapper
public struct Dependency<Value: Sendable>: @unchecked Sendable {
  let keyPath: KeyPath<DependencyValues, Value>
  public init(_ keyPath: KeyPath<DependencyValues, Value>) {
    self.keyPath = keyPath
  }

  public var wrappedValue: Value {
    DependencyValues.current[keyPath: keyPath]
  }
}
