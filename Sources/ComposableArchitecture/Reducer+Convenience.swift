import Foundation

extension Reducer {
    /// - Parameters:
    ///   - toLocalState: A key path that can get/set `State` inside `GlobalState`.
    ///   - toLocalAction: A case path that can extract/embed `Action` from `GlobalAction`.
    /// - Returns: A reducer that works on `GlobalState`, `GlobalAction`, `GlobalEnvironment`.
    public func pullback<GlobalState, GlobalAction>(
        state toLocalState: WritableKeyPath<GlobalState, State>,
        action toLocalAction: CasePath<GlobalAction, Action>
    ) -> Reducer<GlobalState, GlobalAction, Environment> {
        .init { globalState, globalAction, globalEnvironment in
            guard let localAction = toLocalAction.extract(from: globalAction) else { return .none }
            return self.callAsFunction(
                &globalState[keyPath: toLocalState],
                localAction,
                globalEnvironment
            )
            .map(toLocalAction.embed)
        }
    }

    /// - Parameters:
    ///   - toLocalState: A key path that can get/set `State` inside `GlobalState`.
    ///   - toLocalEnvironment: A function that transforms `GlobalEnvironment` into `Environment`.
    /// - Returns: A reducer that works on `GlobalState`, `GlobalAction`, `GlobalEnvironment`.
    public func pullback<GlobalState, GlobalEnvironment>(
        state toLocalState: WritableKeyPath<GlobalState, State>,
        environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment
    ) -> Reducer<GlobalState, Action, GlobalEnvironment> {
        .init { globalState, globalAction, globalEnvironment in
            return self.callAsFunction(
                &globalState[keyPath: toLocalState],
                globalAction,
                toLocalEnvironment(globalEnvironment)
            )
        }
    }

    /// - Parameters:
    ///   - toLocalAction: A case path that can extract/embed `Action` from `GlobalAction`.
    ///   - toLocalEnvironment: A function that transforms `GlobalEnvironment` into `Environment`.
    /// - Returns: A reducer that works on `GlobalState`, `GlobalAction`, `GlobalEnvironment`.
    public func pullback<GlobalAction, GlobalEnvironment>(
        action toLocalAction: CasePath<GlobalAction, Action>,
        environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment
    ) -> Reducer<State, GlobalAction, GlobalEnvironment> {
        .init { globalState, globalAction, globalEnvironment in
            guard let localAction = toLocalAction.extract(from: globalAction) else { return .none }
            return self.callAsFunction(
                &globalState,
                localAction,
                toLocalEnvironment(globalEnvironment)
            )
            .map(toLocalAction.embed)
        }
    }

    /// - Parameters:
    ///   - toLocalAction: A case path that can extract/embed `Action` from `GlobalAction`.
    /// - Returns: A reducer that works on `GlobalState`, `GlobalAction`, `GlobalEnvironment`.
    public func pullback<GlobalAction>(
        action toLocalAction: CasePath<GlobalAction, Action>
    ) -> Reducer<State, GlobalAction, Environment> {
        .init { globalState, globalAction, globalEnvironment in
            guard let localAction = toLocalAction.extract(from: globalAction) else { return .none }
            return self.callAsFunction(
                &globalState,
                localAction,
                globalEnvironment
            )
            .map(toLocalAction.embed)
        }
    }

    /// - Parameters:
    ///   - toLocalState: A key path that can get/set `State` inside `GlobalState`.
    /// - Returns: A reducer that works on `GlobalState`, `GlobalAction`, `GlobalEnvironment`.
    public func pullback<GlobalState>(
        state toLocalState: WritableKeyPath<GlobalState, State>
    ) -> Reducer<GlobalState, Action, Environment> {
        .init { globalState, globalAction, globalEnvironment in
            return self.callAsFunction(
                &globalState[keyPath: toLocalState],
                globalAction,
                globalEnvironment
            )
        }
    }
}
