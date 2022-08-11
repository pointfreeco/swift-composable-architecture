
public protocol DependencyKey {
  associatedtype Value
  static var defaultValue: Value { get }
}

import Foundation
import CombineSchedulers

private enum MainRunLoopKey: DependencyKey {
  static let defaultValue = AnySchedulerOf<RunLoop>.main
}
private enum MainDispatchQueueKey: DependencyKey {
  static let defaultValue = AnySchedulerOf<DispatchQueue>.main
}
private enum DateKey: DependencyKey {
  static let defaultValue = { Date() }
}
private enum UUIDKey: DependencyKey {
  static let defaultValue = { UUID() }
}


public struct DependencyValues {
  static var current = Self()

  private var storage: [AnyHashable: Any] = [:]

  public subscript<Key: DependencyKey>(key: Key.Type) -> Key.Value {
    get {
      let anyDependency = self.storage[ObjectIdentifier(Key.self)]
      return (anyDependency as? Key.Value) ?? Key.defaultValue
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
  public var date: () -> Date {
    get { self[DateKey.self] }
    set { self[DateKey.self] = newValue }
  }
  public var uuid: () -> UUID {
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
