#if DEBUG
import Combine
import Foundation
import XCTestDynamicOverlay


public enum TestStoreKind {
    case exhaustive
    case nonExhaustive
}

/// Universal test store interface that can be used in both Exhaustive and non-Exhaustive mode
/// - note: The reason this isn't using a protocol interface instead of explicit handling is because protocols can't support default arguments (`file`/`line`) and introducing implementation protocol would require more changes in original TCA store, right now we only change access levels which means updating original TCA store whenever upstream changes should be very low effort
public final class TBCTestStore<State, LocalState, Action: Equatable, LocalAction, Environment> {
    public typealias TCATestStoreType = TestStore<State, LocalState, Action, LocalAction, Environment>

    private enum StoreImplementation {
        case exhaustive(TCATestStoreType)
        case nonExhaustive(NonExhaustiveTestStore<State, LocalState, Action, LocalAction, Environment>)
    }
    
    private let storeImplementation: StoreImplementation
    
    internal init(
        kind: TestStoreKind = .exhaustive,
        environment: Environment,
        file: StaticString,
        fromScopedAction: @escaping (LocalAction) -> Action,
        initialState: State,
        line: UInt,
        reducer: Reducer<State, Action, Environment>,
        toLocalState: @escaping (State) -> LocalState
    ) {
        switch kind {
        case .exhaustive:
            storeImplementation = .exhaustive(.init(environment: environment, file: file, fromScopedAction: fromScopedAction, initialState: initialState, line: line, reducer: reducer, toScopedState: toLocalState))
        case .nonExhaustive:
            storeImplementation = .nonExhaustive(.init(environment: environment, file: file, fromLocalAction: fromScopedAction, initialState: initialState, line: line, reducer: reducer, toLocalState: toLocalState))
        }
    }
    
    private init(storeImplementation: StoreImplementation) {
        self.storeImplementation = storeImplementation
    }
    
    public var environment: Environment {
        switch storeImplementation {
        case let .exhaustive(store):
            return store.environment
        case let .nonExhaustive(store):
            return store.environment
        }
    }

    public func assertEffectCompleted() {
        switch storeImplementation {
        case let .exhaustive(store):
            store.completed()
        case let .nonExhaustive(store):
            store.assertEffectCompleted()
        }
    }
    
    /// State accessor for use with XCTAsserts
    /// - note: This isn't allowed with Exhaustive mode and will cause an assertion
    public var state: State {
        switch storeImplementation {
        case .exhaustive:
            preconditionFailure("Don't use state in Exhaustive Test Stores")
        case let .nonExhaustive(store):
            return store.snapshotState
        }
    }
}

extension TBCTestStore where State == LocalState, Action == LocalAction {
    /// Initializes a test store from an initial state, a reducer, and an initial environment.
    ///
    /// - Parameters:
    ///   - kind: The store behaviour kind, exhaustive or not?
    ///   - initialState: The state to start the test from.
    ///   - reducer: A reducer.
    ///   - environment: The environment to start the test from.
    public convenience init(
        kind: TestStoreKind,
        initialState: State,
        reducer: Reducer<State, Action, Environment>,
        environment: Environment,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        self.init(
            kind: kind,
            environment: environment,
            file: file,
            fromScopedAction: { $0 },
            initialState: initialState,
            line: line,
            reducer: reducer,
            toLocalState: { $0 }
        )
    }
}

extension TBCTestStore where LocalState: Equatable {
    public func send(
        _ action: LocalAction,
        file: StaticString = #file,
        line: UInt = #line,
        _ update: ((inout LocalState) throws -> Void)? = nil
    ) {
        switch storeImplementation {
        case let .exhaustive(store):
            store.send(action, update, file: file, line: line)
        case let .nonExhaustive(store):
            store.send(action, file: file, line: line, update)
        }
    }

    @MainActor
    @discardableResult
    public func send(
        _ action: LocalAction,
        file: StaticString = #file,
        line: UInt = #line,
        _ update: ((inout LocalState) throws -> Void)? = nil
    ) async -> TBCTestStoreTask {
        switch storeImplementation {
        case let .exhaustive(store):
            return await TBCTestStoreTask(store.send(action, update, file: file, line: line))
        case let .nonExhaustive(store):
            return TBCTestStoreTask(store.send(action, file: file, line: line, update))
        }
    }

    @MainActor
    public func finish(
        timeout nanoseconds: UInt64? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        switch storeImplementation {
        case let .exhaustive(store):
            return await store.finish(timeout: nanoseconds, file: file, line: line)
        case .nonExhaustive:
            return
        }
    }
}

/// Wrapper around the currently internal `TestStoreTask`
/// can be removed with us removing our custom TestStore implementations
public struct TBCTestStoreTask: Sendable {
    var _cancel: @Sendable () async -> Void
    var _finish: @Sendable () async -> Void

    public func cancel() async { await _cancel() }
    public func finish() async { await _finish() }

    init(_ task: ViewStoreTask) {
        _cancel = { await task.cancel() }
        _finish =  { await task.finish() }
    }

    init(_ task: TestStoreTask) {
        _cancel = { await task.cancel() }
        _finish =  { await task.finish() }
    }
}

extension TBCTestStore where LocalState: Equatable, Action: Equatable {
    public func receive(
        _ expectedAction: Action,
        file: StaticString = #file,
        line: UInt = #line,
        _ update: ((inout LocalState) throws -> Void)? = nil
    ) {
        switch storeImplementation {
        case let .exhaustive(store):
            store.receive(expectedAction, update, file: file, line: line)
        case let .nonExhaustive(store):
            store.receive(expectedAction, file: file, line: line, update)
        }
    }

    @MainActor
    public func receive(
        _ expectedAction: Action,
        file: StaticString = #file,
        line: UInt = #line,
        _ update: ((inout LocalState) throws -> Void)? = nil
    ) async {
        switch storeImplementation {
        case let .exhaustive(store):
            return await store.receive(expectedAction, update, file: file, line: line)
        case let .nonExhaustive(store):
            store.receive(expectedAction, file: file, line: line, update)
        }
    }
}

extension TBCTestStore {
    /// Scopes a store to assert against more local state and actions.
    ///
    /// Useful for testing view store-specific state and actions.
    ///
    /// - Parameters:
    ///   - toLocalState: A function that transforms the reducer's state into more local state. This
    ///     state will be asserted against as it is mutated by the reducer. Useful for testing view
    ///     store state transformations.
    ///   - fromLocalAction: A function that wraps a more local action in the reducer's action.
    ///     Local actions can be "sent" to the store, while any reducer action may be received.
    ///     Useful for testing view store action transformations.
    public func scope<S, A>(
        state toLocalState: @escaping (LocalState) -> S,
        action fromScopedAction: @escaping (A) -> LocalAction
    ) -> TBCTestStore<State, S, Action, A, Environment> {
        switch storeImplementation {
        case let .exhaustive(store):
            return .init(storeImplementation: .exhaustive(store.scope(state: toLocalState, action: fromScopedAction)))
        case let .nonExhaustive(store):
            return .init(storeImplementation: .nonExhaustive(store.scope(state: toLocalState, action: fromScopedAction)))
        }
    }
    
    /// Scopes a store to assert against more local state.
    ///
    /// Useful for testing view store-specific state.
    ///
    /// - Parameter toLocalState: A function that transforms the reducer's state into more local
    ///   state. This state will be asserted against as it is mutated by the reducer. Useful for
    ///   testing view store state transformations.
    public func scope<S>(
        state toLocalState: @escaping (LocalState) -> S
    ) -> TBCTestStore<State, S, Action, LocalAction, Environment> {
        switch storeImplementation {
        case let .exhaustive(store):
            return .init(storeImplementation: .exhaustive(store.scope(state: toLocalState, action: { $0 })))
        case let .nonExhaustive(store):
            return .init(storeImplementation: .nonExhaustive(store.scope(state: toLocalState, action: { $0 })))
        }
    }
}

#endif
