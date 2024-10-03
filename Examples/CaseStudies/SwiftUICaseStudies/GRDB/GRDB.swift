import ComposableArchitecture
import Dispatch
import GRDB

private enum GRDBDefaultDatabaseKey: TestDependencyKey {
  static var testValue: DatabaseQueue /*any DatabaseWriter*/ {
    try! DatabaseQueue()
  }
}

extension DependencyValues {
  public var defaultDatabase: DatabaseQueue /*any DatabaseWriter*/ {
    get { self[GRDBDefaultDatabaseKey.self] }
    set { self[GRDBDefaultDatabaseKey.self] = newValue }
  }
}

public protocol GRDBQuery<Value>: Hashable {
  associatedtype Value
  func fetch(_ db: Database) throws -> Value
}

extension PersistenceReaderKey {
  public static func query<Query: GRDBQuery>(_ query: Query) -> Self
  where Self == GRDBQueryKey<Query> {
    Self(query)
  }
}

public struct GRDBQueryKey<Query: GRDBQuery & Sendable>: Hashable, PersistenceReaderKey
where Query.Value: Sendable {
  let query: Query

  public init(_ query: Query) {
    self.query = query
  }

  public func load(initialValue: Query.Value?) -> Query.Value? {
    do {
      @Dependency(\.defaultDatabase) var defaultDatabase
      return try defaultDatabase.read { db in
        try query.fetch(db)
      }
    } catch {
      return initialValue
    }
  }

  public func subscribe(
    initialValue: Query.Value?,
    didSet: @escaping @Sendable (Query.Value?) -> Void
  ) -> Shared<Query.Value>.Subscription {
    @Dependency(\.defaultDatabase) var defaultDatabase
    let observation = ValueObservation.tracking { db in
      try query.fetch(db)
    }
    let cancellable = observation.start(in: defaultDatabase, scheduling: .mainActorASAP) { error in

    } onChange: { newValue in
      didSet(newValue)
    }
    return Shared.Subscription {
      cancellable.cancel()
    }
  }
}

extension ValueObservationScheduler where Self == MainActorASAPScheduler {
  static var mainActorASAP: Self { Self() }
}

public struct MainActorASAPScheduler: ValueObservationScheduler {
  public init() {}

  public func immediateInitialValue() -> Bool {
    false
  }

  public func schedule(_ action: @escaping @Sendable () -> Void) {
    if DispatchQueue.getSpecific(key: Self.key) == Self.value {
      action()
    } else {
      DispatchQueue.main.async {
        action()
      }
    }
  }

  private static let key: DispatchSpecificKey<UInt8> = {
    let key = DispatchSpecificKey<UInt8>()
    DispatchQueue.main.setSpecific(key: key, value: value)
    return key
  }()

  private static let value: UInt8 = 0
}
