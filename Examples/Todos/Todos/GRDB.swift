import ComposableArchitecture
import GRDB

private enum GRDBDefaultDatabaseQueueKey: TestDependencyKey {
  static var testValue: DatabaseQueue {
    try! DatabaseQueue()
  }
}

extension DependencyValues {
  public var defaultDatabaseQueue: DatabaseQueue {
    get { self[GRDBDefaultDatabaseQueueKey.self] }
    set { self[GRDBDefaultDatabaseQueueKey.self] = newValue }
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
      @Dependency(\.defaultDatabaseQueue) var defaultDatabaseQueue
      return try defaultDatabaseQueue.read { db in
        try query.fetch(db)
      }
    } catch {
      return initialValue
    }
  }

  public func subscribe(
    initialValue: Query.Value?,
    didSet: @escaping (Query.Value?) -> Void
  ) -> Shared<Query.Value>.Subscription {
    @Dependency(\.defaultDatabaseQueue) var defaultDatabaseQueue
    let observation = ValueObservation.tracking { db in
      try query.fetch(db)
    }
    let cancellable = observation.start(in: defaultDatabaseQueue) { error in

    } onChange: { newValue in
      didSet(newValue)
    }
    return Shared.Subscription {
      cancellable.cancel()
    }
  }
}

extension FetchRequest where RowDecoder: FetchableRecord & Identifiable {
  public func fetchIdentifiedArray(_ db: Database) throws -> IdentifiedArrayOf<RowDecoder> {
    try IdentifiedArray(fetchCursor(db))
  }
}
