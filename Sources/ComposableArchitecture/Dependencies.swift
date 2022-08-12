
public protocol DependencyKey {
  associatedtype Value: Sendable
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
  static let defaultValue = { @Sendable in Date() }
}
private enum UUIDKey: DependencyKey {
  static let defaultValue = { @Sendable in UUID() }
}


public struct DependencyValues: Sendable {
  @TaskLocal static var current = Self()

  private var storage: [ObjectIdentifier: any Sendable] = [:]

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

extension ReducerProtocol {
  public func dependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value
  ) -> some ReducerProtocolOf<Self> {
    DependencyKeyWritingReducer(base: self) { $0[keyPath: keyPath] = value }
  }
}

private struct DependencyKeyWritingReducer<Base: ReducerProtocol>: ReducerProtocol {
  let base: Base
  let update: (inout DependencyValues) -> Void

  func reduce(into state: inout Base.State, action: Base.Action) -> Effect<Base.Action, Never> {
    var dependencies = DependencyValues.current
    self.update(&dependencies)
    return DependencyValues.$current.withValue(dependencies) {
      self.base.reduce(into: &state, action: action)
    }
  }

  public func dependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value
  ) -> some ReducerProtocolOf<Self> {
    DependencyKeyWritingReducer(base: self.base) { values in
      self.update(&values)
      values[keyPath: keyPath] = value
    }
  }
}
