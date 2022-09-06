import CombineSchedulers
import Foundation

public protocol DependencyKey {
  associatedtype Value
  static var defaultValue: Value { get }
}

private enum MainRunLoopKey: DependencyKey {
  static let defaultValue = AnySchedulerOf<RunLoop>.main
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
  public var date: () -> Date {
    get { self[DateKey.self] }
    set { self[DateKey.self] = newValue }
  }
  public var uuid: () -> UUID {
    get { self[UUIDKey.self] }
    set { self[UUIDKey.self] = newValue }
  }
  public var openSettings: () async -> Void {
    get { self[OpenSettingsKey.self] }
    set { self[OpenSettingsKey.self] = newValue }
  }
  public var temporaryDirectory: () -> URL {
    get { self[TemporaryDirectoryKey.self] }
    set { self[TemporaryDirectoryKey.self] = newValue }
  }
}

private enum MainQueueKey: DependencyKey {
  static let defaultValue = AnySchedulerOf<DispatchQueue>.main
}

private enum DateKey: DependencyKey {
  static let defaultValue = { Date() }
}

private enum UUIDKey: DependencyKey {
  static let defaultValue = { UUID() }
}

import SwiftUI

private enum OpenSettingsKey: DependencyKey {
  static let defaultValue = {
    await MainActor.run {
      UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
  }
}
private enum TemporaryDirectoryKey: DependencyKey {
  static let defaultValue = { URL(fileURLWithPath: NSTemporaryDirectory()) }
}

public struct DependencyValues {
  private var storage: [AnyHashable: Any] = [:]
  static var current = Self()

  public subscript<Key: DependencyKey>(key: Key.Type) -> Key.Value {
    get {
      guard let dependency = self.storage[ObjectIdentifier(key)] as? Key.Value
      else {
        return Key.defaultValue
      }
      return dependency
    }
    set {
      self.storage[ObjectIdentifier(key)] = newValue
    }
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
