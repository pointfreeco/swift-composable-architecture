
public protocol DependencyKey {
  associatedtype Value: Sendable
  static var testValue: Value { get }
}
public protocol LiveDependencyKey: DependencyKey {
  static var liveValue: Value { get }
}

//extension DependencyKey {
//  public static var testValue: Value { self.liveValue }
//}

import Foundation
import CombineSchedulers

private enum MainRunLoopKey: DependencyKey {
  static let liveValue = AnySchedulerOf<RunLoop>.main
  static let testValue = AnySchedulerOf<RunLoop>.unimplemented
}
private enum MainDispatchQueueKey: DependencyKey {
  static let liveValue = AnySchedulerOf<DispatchQueue>.main
  static let testValue = AnySchedulerOf<DispatchQueue>.unimplemented
}
import XCTestDynamicOverlay
private enum DateKey: DependencyKey {
  static let liveValue = { @Sendable in Date() }
  static let testValue: @Sendable () -> Date = XCTUnimplemented(
    #"Unimplemented: @Dependency(\.date)"#,
    placeholder: Date()
  )
}
private enum UUIDKey: DependencyKey {
  static let liveValue = { @Sendable in UUID() }
  static let testValue: @Sendable () -> UUID = XCTUnimplemented(
    #"Unimplemented: @Dependency(\.uuid)"#,
    placeholder: UUID()
  )
}


public struct DependencyValues: Sendable {
  @TaskLocal public static var current = Self()

  public init() {}

  private var storage: [ObjectIdentifier: any Sendable] = [:]

  public subscript<Key: DependencyKey>(key: Key.Type) -> Key.Value {
    get {
      guard let dependency = self.storage[ObjectIdentifier(Key.self)] as? Key.Value
      else {
        let isTesting = self.storage[ObjectIdentifier(IsTestingKey.self)] as? Bool ?? false
        guard !isTesting
        else {
          return Key.testValue
        }
        return (key as? any LiveDependencyKey.Type)?.liveValue as? Key.Value
          ?? Key.testValue
      }
      return dependency
    }
    set {
      self.storage[ObjectIdentifier(Key.self)] = newValue
    }
  }
}

extension DependencyValues {
  public var mainRunLoop: AnySchedulerOf<RunLoop> {
    get { self[MainRunLoopKey.self] }
    set { self[MainRunLoopKey.self] = newValue }
  }
}
extension DependencyValues {
  public var mainQueue: AnySchedulerOf<DispatchQueue> {
    get { self[MainDispatchQueueKey.self] }
    set { self[MainDispatchQueueKey.self] = newValue }
  }
  public var date: @Sendable () -> Date {
    get { self[DateKey.self] }
    set { self[DateKey.self] = newValue }
  }
  public var uuid: @Sendable () -> UUID {
    get { self[UUIDKey.self] }
    set { self[UUIDKey.self] = newValue }
  }
}



@propertyWrapper
public struct Dependency<Value> {
  public let keyPath: KeyPath<DependencyValues, Value>

  public init(_ keyPath: KeyPath<DependencyValues, Value>) {
    self.keyPath = keyPath
  }

  public var wrappedValue: Value {
    DependencyValues.current[keyPath: self.keyPath]
  }
}

extension Dependency: @unchecked Sendable where Value: Sendable {}

private enum IsTestingKey: DependencyKey {
  static let liveValue = false
  static let testValue = true
}
extension DependencyValues {
  public var isTesting: Bool {
    get { self[IsTestingKey.self] }
    set { self[IsTestingKey.self] = newValue }
  }
}
