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

struct _PerceptionRegistrar: Sendable {
  internal class ValuePerceptionStorage {
    func emit<Element>(_ element: Element) -> Bool { return false }
    func cancel() {}
  }

  private struct ValuesPerceptor {
    private let storage: ValuePerceptionStorage

    internal init(storage: ValuePerceptionStorage) {
      self.storage = storage
    }

    internal func emit<Element>(_ element: Element) -> Bool {
      storage.emit(element)
    }

    internal func cancel() {
      storage.cancel()
    }
  }

  private struct State: @unchecked Sendable {
    private enum PerceptionKind {
      case willSetTracking(@Sendable () -> Void)
      case didSetTracking(@Sendable () -> Void)
      case computed(@Sendable (Any) -> Void)
      case values(ValuesPerceptor)
    }

    private struct Perception {
      private var kind: PerceptionKind
      internal var properties: Set<AnyKeyPath>

      internal init(kind: PerceptionKind, properties: Set<AnyKeyPath>) {
        self.kind = kind
        self.properties = properties
      }

      var willSetTracker: (@Sendable () -> Void)? {
        switch kind {
        case .willSetTracking(let tracker):
          return tracker
        default:
          return nil
        }
      }

      var didSetTracker: (@Sendable () -> Void)? {
        switch kind {
        case .didSetTracking(let tracker):
          return tracker
        default:
          return nil
        }
      }

      var perceptor: (@Sendable (Any) -> Void)? {
        switch kind {
        case .computed(let perceptor):
          return perceptor
        default:
          return nil
        }
      }

      var isValuePerceptor: Bool {
        switch kind {
        case .values:
          return true
        default:
          return false
        }
      }

      func emit<Element>(_ value: Element) -> Bool {
        switch kind {
        case .values(let perceptor):
          return perceptor.emit(value)
        default:
          return false
        }
      }

      func cancel() {
        switch kind {
        case .values(let perceptor):
          perceptor.cancel()
        default:
          break
        }
      }
    }

    private var id = 0
    private var perceptions = [Int: Perception]()
    private var lookups = [AnyKeyPath: Set<Int>]()

    internal mutating func generateId() -> Int {
      defer { id &+= 1 }
      return id
    }

    internal mutating func registerTracking(
      for properties: Set<AnyKeyPath>, willSet perceptor: @Sendable @escaping () -> Void
    ) -> Int {
      let id = generateId()
      perceptions[id] = Perception(kind: .willSetTracking(perceptor), properties: properties)
      for keyPath in properties {
        lookups[keyPath, default: []].insert(id)
      }
      return id
    }

    internal mutating func registerTracking(
      for properties: Set<AnyKeyPath>, didSet perceptor: @Sendable @escaping () -> Void
    ) -> Int {
      let id = generateId()
      perceptions[id] = Perception(kind: .didSetTracking(perceptor), properties: properties)
      for keyPath in properties {
        lookups[keyPath, default: []].insert(id)
      }
      return id
    }

    internal mutating func registerComputedValues(
      for properties: Set<AnyKeyPath>, perceptor: @Sendable @escaping (Any) -> Void
    ) -> Int {
      let id = generateId()
      perceptions[id] = Perception(kind: .computed(perceptor), properties: properties)
      for keyPath in properties {
        lookups[keyPath, default: []].insert(id)
      }
      return id
    }

    internal mutating func registerValues(
      for properties: Set<AnyKeyPath>, storage: ValuePerceptionStorage
    ) -> Int {
      let id = generateId()
      perceptions[id] = Perception(
        kind: .values(ValuesPerceptor(storage: storage)), properties: properties)
      for keyPath in properties {
        lookups[keyPath, default: []].insert(id)
      }
      return id
    }

    internal func valuePerceptors(for keyPath: AnyKeyPath) -> Set<Int> {
      guard let ids = lookups[keyPath] else {
        return []
      }
      return ids.filter { perceptions[$0]?.isValuePerceptor == true }
    }

    internal mutating func cancel(_ id: Int) {
      if let perception = perceptions.removeValue(forKey: id) {
        for keyPath in perception.properties {
          if var ids = lookups[keyPath] {
            ids.remove(id)
            if ids.count == 0 {
              lookups.removeValue(forKey: keyPath)
            } else {
              lookups[keyPath] = ids
            }
          }
        }
        perception.cancel()
      }
    }

    internal mutating func cancelAll() {
      for perception in perceptions.values {
        perception.cancel()
      }
      perceptions.removeAll()
      lookups.removeAll()
    }

    internal mutating func willSet(keyPath: AnyKeyPath) -> [@Sendable () -> Void] {
      var trackers = [@Sendable () -> Void]()
      if let ids = lookups[keyPath] {
        for id in ids {
          if let tracker = perceptions[id]?.willSetTracker {
            trackers.append(tracker)
          }
        }
      }
      return trackers
    }

    internal mutating func didSet<Subject: Perceptible, Member>(keyPath: KeyPath<Subject, Member>)
      -> ([@Sendable (Any) -> Void], [@Sendable () -> Void])
    {
      var perceptors = [@Sendable (Any) -> Void]()
      var trackers = [@Sendable () -> Void]()
      if let ids = lookups[keyPath] {
        for id in ids {
          if let perceptor = perceptions[id]?.perceptor {
            perceptors.append(perceptor)
            cancel(id)
          }
          if let tracker = perceptions[id]?.didSetTracker {
            trackers.append(tracker)
          }
        }
      }
      return (perceptors, trackers)
    }

    internal mutating func emit<Element>(_ value: Element, ids: Set<Int>) {
      for id in ids {
        if perceptions[id]?.emit(value) == true {
          cancel(id)
        }
      }
    }
  }

  internal struct Context: Sendable {
    private let state = _ManagedCriticalState(State())

    internal var id: ObjectIdentifier { state.id }

    internal func registerTracking(
      for properties: Set<AnyKeyPath>, willSet perceptor: @Sendable @escaping () -> Void
    ) -> Int {
      state.withCriticalRegion { $0.registerTracking(for: properties, willSet: perceptor) }
    }

    internal func registerTracking(
      for properties: Set<AnyKeyPath>, didSet perceptor: @Sendable @escaping () -> Void
    ) -> Int {
      state.withCriticalRegion { $0.registerTracking(for: properties, didSet: perceptor) }
    }

    internal func registerComputedValues(
      for properties: Set<AnyKeyPath>, perceptor: @Sendable @escaping (Any) -> Void
    ) -> Int {
      state.withCriticalRegion { $0.registerComputedValues(for: properties, perceptor: perceptor) }
    }

    internal func registerValues(for properties: Set<AnyKeyPath>, storage: ValuePerceptionStorage)
      -> Int
    {
      state.withCriticalRegion { $0.registerValues(for: properties, storage: storage) }
    }

    internal func cancel(_ id: Int) {
      state.withCriticalRegion { $0.cancel(id) }
    }

    internal func cancelAll() {
      state.withCriticalRegion { $0.cancelAll() }
    }

    internal func willSet<Subject: Perceptible, Member>(
      _ subject: Subject,
      keyPath: KeyPath<Subject, Member>
    ) {
      let tracking = state.withCriticalRegion { $0.willSet(keyPath: keyPath) }
      for action in tracking {
        action()
      }
    }

    internal func didSet<Subject: Perceptible, Member>(
      _ subject: Subject,
      keyPath: KeyPath<Subject, Member>
    ) {
      let (ids, (actions, tracking)) = state.withCriticalRegion {
        ($0.valuePerceptors(for: keyPath), $0.didSet(keyPath: keyPath))
      }
      if !ids.isEmpty {
        let value = subject[keyPath: keyPath]
        state.withCriticalRegion { $0.emit(value, ids: ids) }
      }
      for action in tracking {
        action()
      }
      for action in actions {
        action(subject)
      }
    }
  }

  private final class Extent: @unchecked Sendable {
    let context = Context()

    init() {
    }

    deinit {
      context.cancelAll()
    }
  }

  internal var context: Context {
    return extent.context
  }

  private var extent = Extent()

  init() {
  }

  /// Registers access to a specific property for observation.
  ///
  /// - Parameters:
  ///   - subject: An instance of an observable type.
  ///   - keyPath: The key path of an observed property.
  func access<Subject: Perceptible, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    if let trackingPtr = _ThreadLocal.value?
      .assumingMemoryBound(to: PerceptionTracking._AccessList?.self)
    {
      if trackingPtr.pointee == nil {
        trackingPtr.pointee = PerceptionTracking._AccessList()
      }
      trackingPtr.pointee?.addAccess(keyPath: keyPath, context: context)
    }
  }

  /// A property observation called before setting the value of the subject.
  ///
  /// - Parameters:
  ///     - subject: An instance of an observable type.
  ///     - keyPath: The key path of an observed property.
  func willSet<Subject: Perceptible, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    context.willSet(subject, keyPath: keyPath)
  }

  /// A property observation called after setting the value of the subject.
  ///
  /// - Parameters:
  ///   - subject: An instance of an observable type.
  ///   - keyPath: The key path of an observed property.
  func didSet<Subject: Perceptible, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    context.didSet(subject, keyPath: keyPath)
  }

  /// Identifies mutations to the transactions registered for observers.
  ///
  /// This method calls ``willset(_:keypath:)`` before the mutation. Then it
  /// calls ``didset(_:keypath:)`` after the mutation.
  /// - Parameters:
  ///   - of: An instance of an observable type.
  ///   - keyPath: The key path of an observed property.
  func withMutation<Subject: Perceptible, Member, T>(
    of subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ mutation: () throws -> T
  ) rethrows -> T {
    willSet(subject, keyPath: keyPath)
    defer { didSet(subject, keyPath: keyPath) }
    return try mutation()
  }
}
