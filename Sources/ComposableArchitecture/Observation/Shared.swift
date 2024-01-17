#if canImport(Perception)
import Combine
  import Foundation

  public struct _Empty<Element>: AsyncSequence {
    public struct AsyncIterator: AsyncIteratorProtocol {
      public func next() async throws -> Element? {
        nil
      }
    }
    public func makeAsyncIterator() -> AsyncIterator {
      AsyncIterator()
    }
  }

  public protocol SharedPersistence<Value> {
    associatedtype Value
    associatedtype Values: AsyncSequence = _Empty<Value> where Values.Element == Value

    var values: Values { get }
    func get() -> Value?
    func willSet(value: Value, newValue: Value)
    func didSet(oldValue: Value, value: Value)
    mutating func subscribe()
  }

  extension SharedPersistence {
    public func willSet(value _: Value, newValue _: Value) {}
    public func didSet(oldValue _: Value, value _: Value) {}
  }

  extension SharedPersistence where Values == _Empty<Value> {
    public var values: _Empty<Value> {
      _Empty()
    }
  }

  @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
  extension SharedPersistence {
    public static func appStorage<Value: Codable>(
      _ key: String, store: UserDefaults? = nil
    ) -> Self where Self == SharedAppStorage<Value> {
      SharedAppStorage(key, store: store)
    }
  }

  private let decoder = JSONDecoder()
  private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return encoder
  }()

  @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
  public struct SharedAppStorage<Value>: SharedPersistence, Hashable {
    private let _get: () -> Value?
    private let _didSet: (Value) -> Void
    private let key: String
    private let store: UserDefaults
    private let (stream, continuation) = AsyncStream.makeStream(of: Value.self)
    private var observer: Observer?

    private class Observer: NSObject {
      let didChange: () -> Void
      let key: String
      let store: UserDefaults
      init(
        store: UserDefaults,
        key: String,
        didChange: @escaping () -> Void
      ) {
        self.key = key
        self.store = store
        self.didChange = didChange
        super.init()
        store.addObserver(self, forKeyPath: key, context: nil)
      }
      deinit {
        self.removeObserver(self.store, forKeyPath: self.key)
      }
      public override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
      ) {
        self.didChange()
      }
    }

    public init(_ key: String, store: UserDefaults?) where Value: Codable {
      @Dependency(\.userDefaults) var userDefaults
      let store = store ?? userDefaults
      self.key = key
      self._get = {
        try? store.data(forKey: key).map { try decoder.decode(Value.self, from: $0) }
      }
      self._didSet = {
        let data = try! encoder.encode($0)
        if data != store.data(forKey: key) {
          store.set(data, forKey: key)
        }
      }
      self.store = store
    }

    public static func == (lhs: SharedAppStorage, rhs: SharedAppStorage) -> Bool {
      lhs.key == rhs.key && lhs.store == rhs.store
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(self.key)
      hasher.combine(self.store)
    }

    public var values: AsyncStream<Value> {
      self.stream
    }

    public func get() -> Value? {
      self._get()
    }

    public func didSet(oldValue _: Value, value: Value) {
      self._didSet(value)
    }

    public mutating func subscribe() {
      self.observer = Observer(store: store, key: key) { [get = self.get, continuation = self.continuation] in
        guard
          let value = get()
        else { return }
        continuation.yield(value)
      }
    }
  }

  fileprivate let storage = LockIsolated<[AnyHashable: any ReferenceProtocol]>([:])

  @dynamicMemberLookup
  @propertyWrapper
  public struct Shared<Value> {
    fileprivate let reference: any ReferenceProtocol
    private let keyPath: AnyKeyPath

    public init(_ value: Value, fileID: StaticString = #fileID, line: UInt = #line) {
      self.init(reference: Reference(value, fileID: fileID, line: line), keyPath: \Value.self)
    }

    public init(
      wrappedValue value: Value,
      _ persistence: some SharedPersistence<Value>,
      fileID: StaticString = #fileID,
      line: UInt = #line
    ) {

      let reference: any ReferenceProtocol = storage.withValue {
        let reference: any ReferenceProtocol
        if let id = persistence as? AnyHashable {
          if let cachedReference = $0[id] {
            reference = cachedReference
          } else {
            reference = Reference(
              value,
              persistence: persistence,
              fileID: fileID,
              line: line
            )
            $0[id] = reference
          }
        } else {
          return Reference(
            value,
            persistence: persistence,
            fileID: fileID,
            line: line
          )
        }
        return reference
      }

      self.init(
        reference: reference,
        keyPath: \Value.self
      )
    }

    private init(reference: any ReferenceProtocol, keyPath: AnyKeyPath) {
      self.reference = reference
      self.keyPath = keyPath
    }

    public var wrappedValue: Value {
      get {
        if SharedLocals.isAsserting {
          self.snapshot ?? self.currentValue
        } else {
          self.currentValue
        }
      }
      nonmutating set {
        @Dependency(\.sharedChangeTracker) var sharedChangeTracker
        if let sharedChangeTracker {
          if SharedLocals.isAsserting {
            self.snapshot = newValue
          } else {
            if self.snapshot == nil {
              self.snapshot = self.currentValue
            }
            self.currentValue = newValue
            sharedChangeTracker.track(self)
          }
        } else {
          self.currentValue = newValue
          self.snapshot = nil
        }
      }
    }

    public var projectedValue: Shared {
      get { self }
      set { self = newValue }
    }

    fileprivate var currentValue: Value {
      get {
        func open<Root>(_ reference: some ReferenceProtocol<Root>) -> Value {
          reference.currentValue[
            keyPath: unsafeDowncast(self.keyPath, to: KeyPath<Root, Value>.self)
          ]
        }
        return open(self.reference)
      }
      nonmutating set {
        func open<Root>(_ reference: some ReferenceProtocol<Root>) {
          reference.currentValue[
            keyPath: unsafeDowncast(self.keyPath, to: WritableKeyPath<Root, Value>.self)
          ] = newValue
        }
        return open(self.reference)
      }
    }

    fileprivate var snapshot: Value? {
      get {
        func open<Root>(_ reference: some ReferenceProtocol<Root>) -> Value? {
          reference.snapshot?[keyPath: unsafeDowncast(self.keyPath, to: KeyPath<Root, Value>.self)]
        }
        return open(self.reference)
      }
      nonmutating set {
        func open<Root>(_ reference: some ReferenceProtocol<Root>) {
          // TODO: Instead, copy `currentValue` over to `snapshot` when `nil` before applying changes.
          if self.keyPath == \Root.self {
            reference.snapshot = newValue as! Root?
          } else if let newValue {
            reference.snapshot?[
              keyPath: unsafeDowncast(self.keyPath, to: WritableKeyPath<Root, Value>.self)
            ] = newValue
          } else {
            reference.snapshot = nil
          }
        }
        return open(self.reference)
      }
    }

    public subscript<Member>(
      dynamicMember keyPath: WritableKeyPath<Value, Member>
    ) -> Shared<Member> {
      Shared<Member>(reference: self.reference, keyPath: self.keyPath.appending(path: keyPath)!)
    }

    public subscript<Member>(
      dynamicMember keyPath: WritableKeyPath<Value, Member?>
    ) -> Shared<Member>? {
      guard let initialValue = self.wrappedValue[keyPath: keyPath]
      else { return nil }
      return Shared<Member>(
        reference: self.reference,
        // TODO: Can this crash?
        keyPath: self.keyPath.appending(
          path: keyPath.appending(path: \.[default: DefaultSubscript(initialValue)])
        )!
      )
    }

    public func assert(
      _ updateValueToExpectedResult: (inout Value) throws -> Void,
      file: StaticString = #file,
      line: UInt = #line
    ) rethrows where Value: Equatable {
      guard var snapshot = self.snapshot, snapshot != self.currentValue else {
        XCTFail("Expected changes, but none occurred.", file: file, line: line)
        return
      }
      try updateValueToExpectedResult(&snapshot)
      self.snapshot = snapshot
      XCTAssertNoDifference(self.currentValue, self.snapshot, file: file, line: line)
      self.snapshot = nil
    }

    public func skipChanges(
      file: StaticString = #file,
      line: UInt = #line
    ) {
      guard self.snapshot != nil else {
        XCTFail("Expected changes, but none occurred.", file: file, line: line)
        return
      }
      self.snapshot = nil
    }
  }

  extension Shared: @unchecked Sendable where Value: Sendable {}

  // TODO: Can this just be `lhs.reference == rhs.reference`
  extension Shared: Equatable where Value: Equatable {
    public static func == (lhs: Shared, rhs: Shared) -> Bool {
      if SharedLocals.exhaustivity == .on, lhs.reference === rhs.reference {
        return lhs.snapshot ?? lhs.currentValue == rhs.currentValue
      } else {
        return lhs.wrappedValue == rhs.wrappedValue
      }
    }
  }

  extension Shared: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) {
      hasher.combine(self.wrappedValue)
    }
  }

  extension Shared: Identifiable where Value: Identifiable {
    public var id: Value.ID {
      self.wrappedValue.id
    }
  }

  extension Shared: Decodable where Value: Decodable {
    public init(from decoder: Decoder) throws {
      do {
        self.init(try decoder.singleValueContainer().decode(Value.self))
      } catch {
        self.init(try .init(from: decoder))
      }
    }
  }

  extension Shared: Encodable where Value: Encodable {
    public func encode(to encoder: Encoder) throws {
      do {
        var container = encoder.singleValueContainer()
        try container.encode(self.wrappedValue)
      } catch {
        try self.wrappedValue.encode(to: encoder)
      }
    }
  }

  extension Shared: TestDependencyKey where Value: TestDependencyKey {
    public static var testValue: Shared<Value.Value> {
      withDependencies {
        $0[Value.self] = Value.testValue
      } operation: {
        @Dependency(Value.self) var testValue
        return Shared<Value.Value>(testValue)
      }
    }
  }

  extension Shared: DependencyKey where Value: DependencyKey {
    public static var liveValue: Shared<Value.Value> {
      Shared<Value.Value>(Value.liveValue)
    }
  }

  extension Shared: CustomDumpRepresentable {
    public var customDumpValue: Any {
      self.reference
    }
  }

  private protocol ReferenceProtocol<Value>: AnyObject {
    associatedtype Value
    var currentValue: Value { get set }
    var snapshot: Value? { get set }
    func complete()
    func reset()
  }

  @Perceptible
  private final class Reference<Value>: ReferenceProtocol {
    var _currentValue: Value
    @PerceptionIgnored
    var _snapshot: Value?
    let lock = NSRecursiveLock()
    let _$perceptionRegistrar = PerceptionRegistrar(
      isPerceptionCheckingEnabled: _isPlatformPerceptionCheckingEnabled
    )
    let fileID: StaticString
    let line: UInt
    @PerceptionIgnored
    var persistence: (any SharedPersistence<Value>)?
    var currentValue: Value {
      get { self.lock.withLock { self._currentValue } }
      set {
        self.lock.withLock {
          let oldValue = self._currentValue
          self.persistence?.willSet(value: oldValue, newValue: newValue)
          self._currentValue = newValue
          self.persistence?.didSet(oldValue: oldValue, value: newValue)
        }
      }
    }
    var snapshot: Value? {
      get { self.lock.withLock { self._snapshot } }
      set { self.lock.withLock { self._snapshot = newValue } }
    }
    init(
      _ value: Value,
      fileID: StaticString,
      line: UInt
    ) {
      self._currentValue = value
      self.persistence = nil
      self.fileID = fileID
      self.line = line
    }
    init(
      _ value: Value,
      persistence: some SharedPersistence<Value>,
      fileID: StaticString,
      line: UInt
    ) {
      self._currentValue = persistence.get() ?? value
      self.persistence = persistence
      self.fileID = fileID
      self.line = line
      self.persistence?.subscribe()
      Task { @MainActor [weak self] in
        for try await value in persistence.values {
          self?.currentValue = value
        }
      }
    }
    deinit {
      self.complete()
    }
    func complete() {
      if
        let snapshot = self.snapshot,
        let difference = diff(snapshot, self.currentValue, format: .proportional)
      {
        XCTFail(
          """
          Tracked changes to 'Shared<\(Value.self)>@\(self.fileID):\(self.line)' but failed to \
          assert: …

          \(difference.indent(by: 2))

          (Before: −, After: +)

          Call 'Shared<\(Value.self)>.assert' to exhaustively test these changes, or call \
          'skipChanges' to ignore them.
          """
        )
      }
    }
    func reset() {
      self.snapshot = nil
    }
  }

  extension Reference: Equatable where Value: Equatable {
    static func == (lhs: Reference, rhs: Reference) -> Bool {
      if SharedLocals.exhaustivity == .on, lhs === rhs {
        return lhs.snapshot ?? lhs.currentValue == rhs.currentValue
      } else {
        return lhs.currentValue == rhs.currentValue
      }
    }
  }

  extension Reference: CustomDumpRepresentable {
    public var customDumpValue: Any {
      self.currentValue
    }
  }

  extension Reference: _CustomDiffObject {
    public var _customDiffValues: (Any, Any) {
      (self.snapshot ?? self.currentValue, self.currentValue)
    }
  }

  enum SharedLocals {
    @TaskLocal static var exhaustivity: Exhaustivity?
    static var isAsserting: Bool { Self.exhaustivity != nil }
  }

  final class SharedChangeTracker: @unchecked Sendable {
    private struct Value {
      let complete: () -> Void
      let reset: () -> Void
    }

    private var changed = LockIsolated<[ObjectIdentifier: Value]>([:])
    var hasChanges: Bool { !self.changed.value.isEmpty }
    func track<T>(_ shared: Shared<T>) {
      let reference = shared.reference
      self.changed.withValue {
        _ = $0[ObjectIdentifier(reference)] = Value(
          complete: { [weak reference] in
            reference?.complete()
          },
          reset: { [weak reference] in
            reference?.reset()
          }
        )
      }
    }
    func complete() {
      self.changed.withValue {
        for value in $0.values {
          value.complete()
          value.reset()
        }
        $0.removeAll()
      }
    }
    func reset() {
      self.changed.withValue {
        for value in $0.values {
          value.reset()
        }
        $0.removeAll()
      }
    }
  }

  struct SharedChangeTrackerKey: DependencyKey {
    static let liveValue: SharedChangeTracker? = nil
    static let testValue: SharedChangeTracker? = nil
  }

  extension DependencyValues {
    var sharedChangeTracker: SharedChangeTracker? {
      get { self[SharedChangeTrackerKey.self] }
      set { self[SharedChangeTrackerKey.self] = newValue }
    }
  }

  extension Optional {
    fileprivate subscript(default defaultSubscript: DefaultSubscript<Wrapped>) -> Wrapped {
      get { self ?? defaultSubscript.value }
      set {
        defaultSubscript.value = newValue
        if self != nil { self = newValue }
      }
    }
  }

  fileprivate final class DefaultSubscript<Value>: Hashable {
    var value: Value

    init(_ value: Value) {
      self.value = value
    }

    static func == (lhs: DefaultSubscript, rhs: DefaultSubscript) -> Bool {
      lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(ObjectIdentifier(self))
    }
  }
#endif

private enum UserDefaultsKey: DependencyKey {
  static var testValue: UncheckedSendable<UserDefaults> {
    let userDefaults = UserDefaults(suiteName: "test")!
    userDefaults.removePersistentDomain(forName: "test")
    return UncheckedSendable(userDefaults)
  }
  static var previewValue: UncheckedSendable<UserDefaults> {
    Self.testValue
  }
  static let liveValue = UncheckedSendable(UserDefaults.standard)
}

extension DependencyValues {
  public var userDefaults: UserDefaults {
    get { self[UserDefaultsKey.self].value }
    set { self[UserDefaultsKey.self].value = newValue }
  }
}
