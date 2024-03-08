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

extension PersistenceKey {
  public static func query<Request: FetchRequest>(_ request: Request) -> Self
  where Self == GRDBQueryKey<Request> {
    Self(request)
  }
}

public final class GRDBQueryKey<Request: FetchRequest>: PersistenceKey
where Request.RowDecoder: FetchableRecord, Request.RowDecoder: Identifiable {
  let request: Request

  public init(_ request: Request) {
    self.request = request
  }

  public static func == (lhs: GRDBQueryKey, rhs: GRDBQueryKey) -> Bool {
    @Dependency(\.defaultDatabaseQueue) var defaultDatabaseQueue
    return defaultDatabaseQueue.inDatabase { db in
      guard
        let lhsStatement =
          try? lhs.request.makePreparedRequest(db, forSingleResult: false).statement,
        let rhsStatement =
          try? lhs.request.makePreparedRequest(db, forSingleResult: false).statement
      else { return false }
      return lhsStatement.sql == rhsStatement.sql
        && lhsStatement.arguments == rhsStatement.arguments
    }
  }

  public func hash(into hasher: inout Hasher) {
    @Dependency(\.defaultDatabaseQueue) var defaultDatabaseQueue
    try? defaultDatabaseQueue.inDatabase { db in
      let statement = try request.makePreparedRequest(db, forSingleResult: false).statement
      hasher.combine(statement.sql)
      hasher.combine(statement.arguments)
    }
  }

  public func load() -> IdentifiedArrayOf<Request.RowDecoder>? {
    @Dependency(\.defaultDatabaseQueue) var defaultDatabaseQueue
    return try? defaultDatabaseQueue.inDatabase { db in
      try IdentifiedArray(uniqueElements: request.fetchAll(db))
    }
  }

  public func save(_ value: IdentifiedArrayOf<Request.RowDecoder>) {
  }

  public func subscribe(
    didSet: @escaping (IdentifiedArrayOf<Request.RowDecoder>?) -> Void
  ) -> Shared<IdentifiedArrayOf<Request.RowDecoder>>.Subscription {
    @Dependency(\.defaultDatabaseQueue) var defaultDatabaseQueue
    let observation = ValueObservation.tracking { db in
      try self.request.fetchAll(db)
    }
    let cancellable = observation.start(in: defaultDatabaseQueue) { error in

    } onChange: { newValue in
      didSet(IdentifiedArray(uniqueElements: newValue))
    }
    return Shared.Subscription {
      cancellable.cancel()
    }
  }
}
