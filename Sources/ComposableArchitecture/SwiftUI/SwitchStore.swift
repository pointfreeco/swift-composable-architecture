import SwiftUI

/// A view that can switch over a store of enum state and handle each case.
///
/// An application may model parts of its state with enums. For example, app state may differ if a
/// user is logged-in or not:
///
/// ```swift
/// enum State {
///   case loggedIn(LoggedInState)
///   case loggedOut(LoggedOutState)
/// }
/// ```
///
/// In the view layer, a store on this state can switch over each case using a ``SwitchStore`` and
/// a ``CaseLet`` view per case:
///
/// ```swift
/// struct AppView: View {
///   let store: StoreOf<App>
///
///   var body: some View {
///     SwitchStore(self.store) {
///       CaseLet(state: /App.State.loggedIn, action: App.Action.loggedIn) { loggedInStore in
///         LoggedInView(store: loggedInStore)
///       }
///       CaseLet(state: /App.State.loggedOut, action: App.Action.loggedOut) { loggedOutStore in
///         LoggedOutView(store: loggedOutStore)
///       }
///     }
///   }
/// }
/// ```
///
/// If a ``SwitchStore`` does not exhaustively handle every case with a corresponding ``CaseLet``
/// view, a runtime warning will be logged when an unhandled case is encountered. To fall back on a
/// default view instead, introduce a ``Default`` view at the end of the ``SwitchStore``:
///
/// ```swift
/// SwitchStore(self.store) {
///   CaseLet(state: /MyState.first, action: MyAction.first) {
///     FirstView(store: $0)
///   }
///   CaseLet(state: /MyState.second, action: MyAction.second) {
///     SecondView(store: $0)
///   }
///   Default {
///     Text("State is neither first nor second.")
///   }
/// }
/// ```
///
/// See ``ReducerProtocol/ifCaseLet(_:action:then:file:fileID:line:)`` and
/// ``Scope/init(state:action:_:file:fileID:line:)`` for embedding reducers that operate on each
/// case of an enum in reducers that operate on the entire enum.
public struct SwitchStore<State, Action, Content: View>: View {
  public let store: Store<State, Action>
  public let content: Content

  init(
    store: Store<State, Action>,
    @ViewBuilder content: () -> Content
  ) {
    self.store = store
    self.content = content()
  }

  public var body: some View {
    self.content
      .environmentObject(StoreObservableObject(store: self.store))
  }
}

/// A view that handles a specific case of enum state in a ``SwitchStore``.
public struct CaseLet<EnumState, EnumAction, CaseState, CaseAction, Content: View>: View {
  @EnvironmentObject private var store: StoreObservableObject<EnumState, EnumAction>
  public let toCaseState: (EnumState) -> CaseState?
  public let fromCaseAction: (CaseAction) -> EnumAction
  public let content: (Store<CaseState, CaseAction>) -> Content

  /// Initializes a ``CaseLet`` view that computes content depending on if a store of enum state
  /// matches a particular case.
  ///
  /// - Parameters:
  ///   - toCaseState: A function that can extract a case of switch store state, which can be
  ///     specified using case path literal syntax, _e.g._ `/State.case`.
  ///   - fromCaseAction: A function that can embed a case action in a switch store action.
  ///   - content: A function that is given a store of the given case's state and returns a view
  ///     that is visible only when the switch store's state matches.
  public init(
    state toCaseState: @escaping (EnumState) -> CaseState?,
    action fromCaseAction: @escaping (CaseAction) -> EnumAction,
    @ViewBuilder then content: @escaping (Store<CaseState, CaseAction>) -> Content
  ) {
    self.toCaseState = toCaseState
    self.fromCaseAction = fromCaseAction
    self.content = content
  }

  public var body: some View {
    IfLetStore(
      self.store.wrappedValue.scope(
        state: self.toCaseState,
        action: self.fromCaseAction
      ),
      then: self.content
    )
  }
}

extension CaseLet where EnumAction == CaseAction {
  /// Initializes a ``CaseLet`` view that computes content depending on if a store of enum state
  /// matches a particular case.
  ///
  /// - Parameters:
  ///   - toCaseState: A function that can extract a case of switch store state, which can be
  ///     specified using case path literal syntax, _e.g._ `/State.case`.
  ///   - content: A function that is given a store of the given case's state and returns a view
  ///     that is visible only when the switch store's state matches.
  public init(
    state toCaseState: @escaping (EnumState) -> CaseState?,
    @ViewBuilder then content: @escaping (Store<CaseState, CaseAction>) -> Content
  ) {
    self.init(
      state: toCaseState,
      action: { $0 },
      then: content
    )
  }
}

/// A view that covers any cases that aren't addressed in a ``SwitchStore``.
///
/// If you wish to use ``SwitchStore`` in a non-exhaustive manner (i.e. you do not want to provide
/// a ``CaseLet`` for each case of the enum), then you must insert a ``Default`` view at the end of
/// the ``SwitchStore``'s body.
public struct Default<Content: View>: View {
  private let content: Content

  /// Initializes a ``Default`` view that computes content depending on if a store of enum state
  /// does not match a particular case.
  ///
  /// - Parameter content: A function that returns a view that is visible only when the switch
  ///   store's state does not match a preceding ``CaseLet`` view.
  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    self.content
  }
}

extension SwitchStore {
  public init<State1, Action1, Content1, DefaultContent>(
    _ store: Store<State, Action>,
    @ViewBuilder content: () -> TupleView<
      (
        CaseLet<State, Action, State1, Action1, Content1>,
        Default<DefaultContent>
      )
    >
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        CaseLet<State, Action, State1, Action1, Content1>,
        Default<DefaultContent>
      >
    >
  {
    let content = content().value
    self.init(store: store) {
      return WithViewStore(store, removeDuplicates: { enumTag($0) == enumTag($1) }) { viewStore in
        if content.0.toCaseState(viewStore.state) != nil {
          content.0
        } else {
          content.1
        }
      }
    }
  }

  public init<State1, Action1, Content1>(
    _ store: Store<State, Action>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: () -> CaseLet<State, Action, State1, Action1, Content1>
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        CaseLet<State, Action, State1, Action1, Content1>,
        Default<_ExhaustivityCheckView<State, Action>>
      >
    >
  {
    self.init(store) {
      content()
      Default { _ExhaustivityCheckView<State, Action>(file: file, fileID: fileID, line: line) }
    }
  }

  public init<State1, Action1, Content1, State2, Action2, Content2, DefaultContent>(
    _ store: Store<State, Action>,
    @ViewBuilder content: () -> TupleView<
      (
        CaseLet<State, Action, State1, Action1, Content1>,
        CaseLet<State, Action, State2, Action2, Content2>,
        Default<DefaultContent>
      )
    >
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        _ConditionalContent<
          CaseLet<State, Action, State1, Action1, Content1>,
          CaseLet<State, Action, State2, Action2, Content2>
        >,
        Default<DefaultContent>
      >
    >
  {
    let content = content().value
    self.init(store: store) {
      return WithViewStore(store, removeDuplicates: { enumTag($0) == enumTag($1) }) { viewStore in
        if content.0.toCaseState(viewStore.state) != nil {
          content.0
        } else if content.1.toCaseState(viewStore.state) != nil {
          content.1
        } else {
          content.2
        }
      }
    }
  }

  public init<State1, Action1, Content1, State2, Action2, Content2>(
    _ store: Store<State, Action>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: () -> TupleView<
      (
        CaseLet<State, Action, State1, Action1, Content1>,
        CaseLet<State, Action, State2, Action2, Content2>
      )
    >
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        _ConditionalContent<
          CaseLet<State, Action, State1, Action1, Content1>,
          CaseLet<State, Action, State2, Action2, Content2>
        >,
        Default<_ExhaustivityCheckView<State, Action>>
      >
    >
  {
    let content = content()
    self.init(store) {
      content.value.0
      content.value.1
      Default { _ExhaustivityCheckView<State, Action>(file: file, fileID: fileID, line: line) }
    }
  }

  public init<
    State1, Action1, Content1,
    State2, Action2, Content2,
    State3, Action3, Content3,
    DefaultContent
  >(
    _ store: Store<State, Action>,
    @ViewBuilder content: () -> TupleView<
      (
        CaseLet<State, Action, State1, Action1, Content1>,
        CaseLet<State, Action, State2, Action2, Content2>,
        CaseLet<State, Action, State3, Action3, Content3>,
        Default<DefaultContent>
      )
    >
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        _ConditionalContent<
          CaseLet<State, Action, State1, Action1, Content1>,
          CaseLet<State, Action, State2, Action2, Content2>
        >,
        _ConditionalContent<
          CaseLet<State, Action, State3, Action3, Content3>,
          Default<DefaultContent>
        >
      >
    >
  {
    let content = content().value
    self.init(store: store) {
      return WithViewStore(store, removeDuplicates: { enumTag($0) == enumTag($1) }) { viewStore in
        if content.0.toCaseState(viewStore.state) != nil {
          content.0
        } else if content.1.toCaseState(viewStore.state) != nil {
          content.1
        } else if content.2.toCaseState(viewStore.state) != nil {
          content.2
        } else {
          content.3
        }
      }
    }
  }

  public init<State1, Action1, Content1, State2, Action2, Content2, State3, Action3, Content3>(
    _ store: Store<State, Action>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: () -> TupleView<
      (
        CaseLet<State, Action, State1, Action1, Content1>,
        CaseLet<State, Action, State2, Action2, Content2>,
        CaseLet<State, Action, State3, Action3, Content3>
      )
    >
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        _ConditionalContent<
          CaseLet<State, Action, State1, Action1, Content1>,
          CaseLet<State, Action, State2, Action2, Content2>
        >,
        _ConditionalContent<
          CaseLet<State, Action, State3, Action3, Content3>,
          Default<_ExhaustivityCheckView<State, Action>>
        >
      >
    >
  {
    let content = content()
    self.init(store) {
      content.value.0
      content.value.1
      content.value.2
      Default { _ExhaustivityCheckView<State, Action>(file: file, fileID: fileID, line: line) }
    }
  }

  public init<
    State1, Action1, Content1,
    State2, Action2, Content2,
    State3, Action3, Content3,
    State4, Action4, Content4,
    DefaultContent
  >(
    _ store: Store<State, Action>,
    @ViewBuilder content: () -> TupleView<
      (
        CaseLet<State, Action, State1, Action1, Content1>,
        CaseLet<State, Action, State2, Action2, Content2>,
        CaseLet<State, Action, State3, Action3, Content3>,
        CaseLet<State, Action, State4, Action4, Content4>,
        Default<DefaultContent>
      )
    >
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        _ConditionalContent<
          _ConditionalContent<
            CaseLet<State, Action, State1, Action1, Content1>,
            CaseLet<State, Action, State2, Action2, Content2>
          >,
          _ConditionalContent<
            CaseLet<State, Action, State3, Action3, Content3>,
            CaseLet<State, Action, State4, Action4, Content4>
          >
        >,
        Default<DefaultContent>
      >
    >
  {
    let content = content().value
    self.init(store: store) {
      return WithViewStore(store, removeDuplicates: { enumTag($0) == enumTag($1) }) { viewStore in
        if content.0.toCaseState(viewStore.state) != nil {
          content.0
        } else if content.1.toCaseState(viewStore.state) != nil {
          content.1
        } else if content.2.toCaseState(viewStore.state) != nil {
          content.2
        } else if content.3.toCaseState(viewStore.state) != nil {
          content.3
        } else {
          content.4
        }
      }
    }
  }

  public init<
    State1, Action1, Content1,
    State2, Action2, Content2,
    State3, Action3, Content3,
    State4, Action4, Content4
  >(
    _ store: Store<State, Action>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: () -> TupleView<
      (
        CaseLet<State, Action, State1, Action1, Content1>,
        CaseLet<State, Action, State2, Action2, Content2>,
        CaseLet<State, Action, State3, Action3, Content3>,
        CaseLet<State, Action, State4, Action4, Content4>
      )
    >
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        _ConditionalContent<
          _ConditionalContent<
            CaseLet<State, Action, State1, Action1, Content1>,
            CaseLet<State, Action, State2, Action2, Content2>
          >,
          _ConditionalContent<
            CaseLet<State, Action, State3, Action3, Content3>,
            CaseLet<State, Action, State4, Action4, Content4>
          >
        >,
        Default<_ExhaustivityCheckView<State, Action>>
      >
    >
  {
    let content = content()
    self.init(store) {
      content.value.0
      content.value.1
      content.value.2
      content.value.3
      Default { _ExhaustivityCheckView<State, Action>(file: file, fileID: fileID, line: line) }
    }
  }

  public init<
    State1, Action1, Content1,
    State2, Action2, Content2,
    State3, Action3, Content3,
    State4, Action4, Content4,
    State5, Action5, Content5,
    DefaultContent
  >(
    _ store: Store<State, Action>,
    @ViewBuilder content: () -> TupleView<
      (
        CaseLet<State, Action, State1, Action1, Content1>,
        CaseLet<State, Action, State2, Action2, Content2>,
        CaseLet<State, Action, State3, Action3, Content3>,
        CaseLet<State, Action, State4, Action4, Content4>,
        CaseLet<State, Action, State5, Action5, Content5>,
        Default<DefaultContent>
      )
    >
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        _ConditionalContent<
          _ConditionalContent<
            CaseLet<State, Action, State1, Action1, Content1>,
            CaseLet<State, Action, State2, Action2, Content2>
          >,
          _ConditionalContent<
            CaseLet<State, Action, State3, Action3, Content3>,
            CaseLet<State, Action, State4, Action4, Content4>
          >
        >,
        _ConditionalContent<
          CaseLet<State, Action, State5, Action5, Content5>,
          Default<DefaultContent>
        >
      >
    >
  {
    let content = content().value
    self.init(store: store) {
      return WithViewStore(store, removeDuplicates: { enumTag($0) == enumTag($1) }) { viewStore in
        if content.0.toCaseState(viewStore.state) != nil {
          content.0
        } else if content.1.toCaseState(viewStore.state) != nil {
          content.1
        } else if content.2.toCaseState(viewStore.state) != nil {
          content.2
        } else if content.3.toCaseState(viewStore.state) != nil {
          content.3
        } else if content.4.toCaseState(viewStore.state) != nil {
          content.4
        } else {
          content.5
        }
      }
    }
  }

  public init<
    State1, Action1, Content1,
    State2, Action2, Content2,
    State3, Action3, Content3,
    State4, Action4, Content4,
    State5, Action5, Content5
  >(
    _ store: Store<State, Action>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: () -> TupleView<
      (
        CaseLet<State, Action, State1, Action1, Content1>,
        CaseLet<State, Action, State2, Action2, Content2>,
        CaseLet<State, Action, State3, Action3, Content3>,
        CaseLet<State, Action, State4, Action4, Content4>,
        CaseLet<State, Action, State5, Action5, Content5>
      )
    >
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        _ConditionalContent<
          _ConditionalContent<
            CaseLet<State, Action, State1, Action1, Content1>,
            CaseLet<State, Action, State2, Action2, Content2>
          >,
          _ConditionalContent<
            CaseLet<State, Action, State3, Action3, Content3>,
            CaseLet<State, Action, State4, Action4, Content4>
          >
        >,
        _ConditionalContent<
          CaseLet<State, Action, State5, Action5, Content5>,
          Default<_ExhaustivityCheckView<State, Action>>
        >
      >
    >
  {
    let content = content()
    self.init(store) {
      content.value.0
      content.value.1
      content.value.2
      content.value.3
      content.value.4
      Default { _ExhaustivityCheckView<State, Action>(file: file, fileID: fileID, line: line) }
    }
  }

  public init<
    State1, Action1, Content1,
    State2, Action2, Content2,
    State3, Action3, Content3,
    State4, Action4, Content4,
    State5, Action5, Content5,
    State6, Action6, Content6,
    DefaultContent
  >(
    _ store: Store<State, Action>,
    @ViewBuilder content: () -> TupleView<
      (
        CaseLet<State, Action, State1, Action1, Content1>,
        CaseLet<State, Action, State2, Action2, Content2>,
        CaseLet<State, Action, State3, Action3, Content3>,
        CaseLet<State, Action, State4, Action4, Content4>,
        CaseLet<State, Action, State5, Action5, Content5>,
        CaseLet<State, Action, State6, Action6, Content6>,
        Default<DefaultContent>
      )
    >
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        _ConditionalContent<
          _ConditionalContent<
            CaseLet<State, Action, State1, Action1, Content1>,
            CaseLet<State, Action, State2, Action2, Content2>
          >,
          _ConditionalContent<
            CaseLet<State, Action, State3, Action3, Content3>,
            CaseLet<State, Action, State4, Action4, Content4>
          >
        >,
        _ConditionalContent<
          _ConditionalContent<
            CaseLet<State, Action, State5, Action5, Content5>,
            CaseLet<State, Action, State6, Action6, Content6>
          >,
          Default<DefaultContent>
        >
      >
    >
  {
    let content = content().value
    self.init(store: store) {
      return WithViewStore(store, removeDuplicates: { enumTag($0) == enumTag($1) }) { viewStore in
        if content.0.toCaseState(viewStore.state) != nil {
          content.0
        } else if content.1.toCaseState(viewStore.state) != nil {
          content.1
        } else if content.2.toCaseState(viewStore.state) != nil {
          content.2
        } else if content.3.toCaseState(viewStore.state) != nil {
          content.3
        } else if content.4.toCaseState(viewStore.state) != nil {
          content.4
        } else if content.5.toCaseState(viewStore.state) != nil {
          content.5
        } else {
          content.6
        }
      }
    }
  }

  public init<
    State1, Action1, Content1,
    State2, Action2, Content2,
    State3, Action3, Content3,
    State4, Action4, Content4,
    State5, Action5, Content5,
    State6, Action6, Content6
  >(
    _ store: Store<State, Action>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: () -> TupleView<
      (
        CaseLet<State, Action, State1, Action1, Content1>,
        CaseLet<State, Action, State2, Action2, Content2>,
        CaseLet<State, Action, State3, Action3, Content3>,
        CaseLet<State, Action, State4, Action4, Content4>,
        CaseLet<State, Action, State5, Action5, Content5>,
        CaseLet<State, Action, State6, Action6, Content6>
      )
    >
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        _ConditionalContent<
          _ConditionalContent<
            CaseLet<State, Action, State1, Action1, Content1>,
            CaseLet<State, Action, State2, Action2, Content2>
          >,
          _ConditionalContent<
            CaseLet<State, Action, State3, Action3, Content3>,
            CaseLet<State, Action, State4, Action4, Content4>
          >
        >,
        _ConditionalContent<
          _ConditionalContent<
            CaseLet<State, Action, State5, Action5, Content5>,
            CaseLet<State, Action, State6, Action6, Content6>
          >,
          Default<_ExhaustivityCheckView<State, Action>>
        >
      >
    >
  {
    let content = content()
    self.init(store) {
      content.value.0
      content.value.1
      content.value.2
      content.value.3
      content.value.4
      content.value.5
      Default { _ExhaustivityCheckView<State, Action>(file: file, fileID: fileID, line: line) }
    }
  }

  public init<
    State1, Action1, Content1,
    State2, Action2, Content2,
    State3, Action3, Content3,
    State4, Action4, Content4,
    State5, Action5, Content5,
    State6, Action6, Content6,
    State7, Action7, Content7,
    DefaultContent
  >(
    _ store: Store<State, Action>,
    @ViewBuilder content: () -> TupleView<
      (
        CaseLet<State, Action, State1, Action1, Content1>,
        CaseLet<State, Action, State2, Action2, Content2>,
        CaseLet<State, Action, State3, Action3, Content3>,
        CaseLet<State, Action, State4, Action4, Content4>,
        CaseLet<State, Action, State5, Action5, Content5>,
        CaseLet<State, Action, State6, Action6, Content6>,
        CaseLet<State, Action, State7, Action7, Content7>,
        Default<DefaultContent>
      )
    >
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        _ConditionalContent<
          _ConditionalContent<
            CaseLet<State, Action, State1, Action1, Content1>,
            CaseLet<State, Action, State2, Action2, Content2>
          >,
          _ConditionalContent<
            CaseLet<State, Action, State3, Action3, Content3>,
            CaseLet<State, Action, State4, Action4, Content4>
          >
        >,
        _ConditionalContent<
          _ConditionalContent<
            CaseLet<State, Action, State5, Action5, Content5>,
            CaseLet<State, Action, State6, Action6, Content6>
          >,
          _ConditionalContent<
            CaseLet<State, Action, State7, Action7, Content7>,
            Default<DefaultContent>
          >
        >
      >
    >
  {
    let content = content().value
    self.init(store: store) {
      return WithViewStore(store, removeDuplicates: { enumTag($0) == enumTag($1) }) { viewStore in
        if content.0.toCaseState(viewStore.state) != nil {
          content.0
        } else if content.1.toCaseState(viewStore.state) != nil {
          content.1
        } else if content.2.toCaseState(viewStore.state) != nil {
          content.2
        } else if content.3.toCaseState(viewStore.state) != nil {
          content.3
        } else if content.4.toCaseState(viewStore.state) != nil {
          content.4
        } else if content.5.toCaseState(viewStore.state) != nil {
          content.5
        } else if content.6.toCaseState(viewStore.state) != nil {
          content.6
        } else {
          content.7
        }
      }
    }
  }

  public init<
    State1, Action1, Content1,
    State2, Action2, Content2,
    State3, Action3, Content3,
    State4, Action4, Content4,
    State5, Action5, Content5,
    State6, Action6, Content6,
    State7, Action7, Content7
  >(
    _ store: Store<State, Action>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: () -> TupleView<
      (
        CaseLet<State, Action, State1, Action1, Content1>,
        CaseLet<State, Action, State2, Action2, Content2>,
        CaseLet<State, Action, State3, Action3, Content3>,
        CaseLet<State, Action, State4, Action4, Content4>,
        CaseLet<State, Action, State5, Action5, Content5>,
        CaseLet<State, Action, State6, Action6, Content6>,
        CaseLet<State, Action, State7, Action7, Content7>
      )
    >
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        _ConditionalContent<
          _ConditionalContent<
            CaseLet<State, Action, State1, Action1, Content1>,
            CaseLet<State, Action, State2, Action2, Content2>
          >,
          _ConditionalContent<
            CaseLet<State, Action, State3, Action3, Content3>,
            CaseLet<State, Action, State4, Action4, Content4>
          >
        >,
        _ConditionalContent<
          _ConditionalContent<
            CaseLet<State, Action, State5, Action5, Content5>,
            CaseLet<State, Action, State6, Action6, Content6>
          >,
          _ConditionalContent<
            CaseLet<State, Action, State7, Action7, Content7>,
            Default<_ExhaustivityCheckView<State, Action>>
          >
        >
      >
    >
  {
    let content = content()
    self.init(store) {
      content.value.0
      content.value.1
      content.value.2
      content.value.3
      content.value.4
      content.value.5
      content.value.6
      Default { _ExhaustivityCheckView<State, Action>(file: file, fileID: fileID, line: line) }
    }
  }

  public init<
    State1, Action1, Content1,
    State2, Action2, Content2,
    State3, Action3, Content3,
    State4, Action4, Content4,
    State5, Action5, Content5,
    State6, Action6, Content6,
    State7, Action7, Content7,
    State8, Action8, Content8,
    DefaultContent
  >(
    _ store: Store<State, Action>,
    @ViewBuilder content: () -> TupleView<
      (
        CaseLet<State, Action, State1, Action1, Content1>,
        CaseLet<State, Action, State2, Action2, Content2>,
        CaseLet<State, Action, State3, Action3, Content3>,
        CaseLet<State, Action, State4, Action4, Content4>,
        CaseLet<State, Action, State5, Action5, Content5>,
        CaseLet<State, Action, State6, Action6, Content6>,
        CaseLet<State, Action, State7, Action7, Content7>,
        CaseLet<State, Action, State8, Action8, Content8>,
        Default<DefaultContent>
      )
    >
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        _ConditionalContent<
          _ConditionalContent<
            _ConditionalContent<
              CaseLet<State, Action, State1, Action1, Content1>,
              CaseLet<State, Action, State2, Action2, Content2>
            >,
            _ConditionalContent<
              CaseLet<State, Action, State3, Action3, Content3>,
              CaseLet<State, Action, State4, Action4, Content4>
            >
          >,
          _ConditionalContent<
            _ConditionalContent<
              CaseLet<State, Action, State5, Action5, Content5>,
              CaseLet<State, Action, State6, Action6, Content6>
            >,
            _ConditionalContent<
              CaseLet<State, Action, State7, Action7, Content7>,
              CaseLet<State, Action, State8, Action8, Content8>
            >
          >
        >,
        Default<DefaultContent>
      >
    >
  {
    let content = content().value
    self.init(store: store) {
      return WithViewStore(store, removeDuplicates: { enumTag($0) == enumTag($1) }) { viewStore in
        if content.0.toCaseState(viewStore.state) != nil {
          content.0
        } else if content.1.toCaseState(viewStore.state) != nil {
          content.1
        } else if content.2.toCaseState(viewStore.state) != nil {
          content.2
        } else if content.3.toCaseState(viewStore.state) != nil {
          content.3
        } else if content.4.toCaseState(viewStore.state) != nil {
          content.4
        } else if content.5.toCaseState(viewStore.state) != nil {
          content.5
        } else if content.6.toCaseState(viewStore.state) != nil {
          content.6
        } else if content.7.toCaseState(viewStore.state) != nil {
          content.7
        } else {
          content.8
        }
      }
    }
  }

  public init<
    State1, Action1, Content1,
    State2, Action2, Content2,
    State3, Action3, Content3,
    State4, Action4, Content4,
    State5, Action5, Content5,
    State6, Action6, Content6,
    State7, Action7, Content7,
    State8, Action8, Content8
  >(
    _ store: Store<State, Action>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: () -> TupleView<
      (
        CaseLet<State, Action, State1, Action1, Content1>,
        CaseLet<State, Action, State2, Action2, Content2>,
        CaseLet<State, Action, State3, Action3, Content3>,
        CaseLet<State, Action, State4, Action4, Content4>,
        CaseLet<State, Action, State5, Action5, Content5>,
        CaseLet<State, Action, State6, Action6, Content6>,
        CaseLet<State, Action, State7, Action7, Content7>,
        CaseLet<State, Action, State8, Action8, Content8>
      )
    >
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        _ConditionalContent<
          _ConditionalContent<
            _ConditionalContent<
              CaseLet<State, Action, State1, Action1, Content1>,
              CaseLet<State, Action, State2, Action2, Content2>
            >,
            _ConditionalContent<
              CaseLet<State, Action, State3, Action3, Content3>,
              CaseLet<State, Action, State4, Action4, Content4>
            >
          >,
          _ConditionalContent<
            _ConditionalContent<
              CaseLet<State, Action, State5, Action5, Content5>,
              CaseLet<State, Action, State6, Action6, Content6>
            >,
            _ConditionalContent<
              CaseLet<State, Action, State7, Action7, Content7>,
              CaseLet<State, Action, State8, Action8, Content8>
            >
          >
        >,
        Default<_ExhaustivityCheckView<State, Action>>
      >
    >
  {
    let content = content()
    self.init(store) {
      content.value.0
      content.value.1
      content.value.2
      content.value.3
      content.value.4
      content.value.5
      content.value.6
      content.value.7
      Default { _ExhaustivityCheckView<State, Action>(file: file, fileID: fileID, line: line) }
    }
  }

  public init<
    State1, Action1, Content1,
    State2, Action2, Content2,
    State3, Action3, Content3,
    State4, Action4, Content4,
    State5, Action5, Content5,
    State6, Action6, Content6,
    State7, Action7, Content7,
    State8, Action8, Content8,
    State9, Action9, Content9,
    DefaultContent
  >(
    _ store: Store<State, Action>,
    @ViewBuilder content: () -> TupleView<
      (
        CaseLet<State, Action, State1, Action1, Content1>,
        CaseLet<State, Action, State2, Action2, Content2>,
        CaseLet<State, Action, State3, Action3, Content3>,
        CaseLet<State, Action, State4, Action4, Content4>,
        CaseLet<State, Action, State5, Action5, Content5>,
        CaseLet<State, Action, State6, Action6, Content6>,
        CaseLet<State, Action, State7, Action7, Content7>,
        CaseLet<State, Action, State8, Action8, Content8>,
        CaseLet<State, Action, State9, Action9, Content9>,
        Default<DefaultContent>
      )
    >
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        _ConditionalContent<
          _ConditionalContent<
            _ConditionalContent<
              CaseLet<State, Action, State1, Action1, Content1>,
              CaseLet<State, Action, State2, Action2, Content2>
            >,
            _ConditionalContent<
              CaseLet<State, Action, State3, Action3, Content3>,
              CaseLet<State, Action, State4, Action4, Content4>
            >
          >,
          _ConditionalContent<
            _ConditionalContent<
              CaseLet<State, Action, State5, Action5, Content5>,
              CaseLet<State, Action, State6, Action6, Content6>
            >,
            _ConditionalContent<
              CaseLet<State, Action, State7, Action7, Content7>,
              CaseLet<State, Action, State8, Action8, Content8>
            >
          >
        >,
        _ConditionalContent<
          CaseLet<State, Action, State9, Action9, Content9>,
          Default<DefaultContent>
        >
      >
    >
  {
    let content = content().value
    self.init(store: store) {
      return WithViewStore(store, removeDuplicates: { enumTag($0) == enumTag($1) }) { viewStore in
        if content.0.toCaseState(viewStore.state) != nil {
          content.0
        } else if content.1.toCaseState(viewStore.state) != nil {
          content.1
        } else if content.2.toCaseState(viewStore.state) != nil {
          content.2
        } else if content.3.toCaseState(viewStore.state) != nil {
          content.3
        } else if content.4.toCaseState(viewStore.state) != nil {
          content.4
        } else if content.5.toCaseState(viewStore.state) != nil {
          content.5
        } else if content.6.toCaseState(viewStore.state) != nil {
          content.6
        } else if content.7.toCaseState(viewStore.state) != nil {
          content.7
        } else if content.8.toCaseState(viewStore.state) != nil {
          content.8
        } else {
          content.9
        }
      }
    }
  }

  public init<
    State1, Action1, Content1,
    State2, Action2, Content2,
    State3, Action3, Content3,
    State4, Action4, Content4,
    State5, Action5, Content5,
    State6, Action6, Content6,
    State7, Action7, Content7,
    State8, Action8, Content8,
    State9, Action9, Content9
  >(
    _ store: Store<State, Action>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: () -> TupleView<
      (
        CaseLet<State, Action, State1, Action1, Content1>,
        CaseLet<State, Action, State2, Action2, Content2>,
        CaseLet<State, Action, State3, Action3, Content3>,
        CaseLet<State, Action, State4, Action4, Content4>,
        CaseLet<State, Action, State5, Action5, Content5>,
        CaseLet<State, Action, State6, Action6, Content6>,
        CaseLet<State, Action, State7, Action7, Content7>,
        CaseLet<State, Action, State8, Action8, Content8>,
        CaseLet<State, Action, State9, Action9, Content9>
      )
    >
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        _ConditionalContent<
          _ConditionalContent<
            _ConditionalContent<
              CaseLet<State, Action, State1, Action1, Content1>,
              CaseLet<State, Action, State2, Action2, Content2>
            >,
            _ConditionalContent<
              CaseLet<State, Action, State3, Action3, Content3>,
              CaseLet<State, Action, State4, Action4, Content4>
            >
          >,
          _ConditionalContent<
            _ConditionalContent<
              CaseLet<State, Action, State5, Action5, Content5>,
              CaseLet<State, Action, State6, Action6, Content6>
            >,
            _ConditionalContent<
              CaseLet<State, Action, State7, Action7, Content7>,
              CaseLet<State, Action, State8, Action8, Content8>
            >
          >
        >,
        _ConditionalContent<
          CaseLet<State, Action, State9, Action9, Content9>,
          Default<_ExhaustivityCheckView<State, Action>>
        >
      >
    >
  {
    let content = content()
    self.init(store) {
      content.value.0
      content.value.1
      content.value.2
      content.value.3
      content.value.4
      content.value.5
      content.value.6
      content.value.7
      content.value.8
      Default { _ExhaustivityCheckView<State, Action>(file: file, fileID: fileID, line: line) }
    }
  }
}

public struct _ExhaustivityCheckView<State, Action>: View {
  @EnvironmentObject private var store: StoreObservableObject<State, Action>
  let file: StaticString
  let fileID: StaticString
  let line: UInt

  public var body: some View {
    #if DEBUG
      let message = """
        Warning: SwitchStore.body@\(self.file):\(self.line)

        "\(debugCaseOutput(self.store.wrappedValue.state.value))" was encountered by a \
        "SwitchStore" that does not handle this case.

        Make sure that you exhaustively provide a "CaseLet" view for each case in "\(State.self)", \
        or provide a "Default" view at the end of the "SwitchStore".
        """
      return VStack(spacing: 17) {
        #if os(macOS)
          Text("⚠️")
        #else
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.largeTitle)
        #endif

        Text(message)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .foregroundColor(.white)
      .padding()
      .background(Color.red.edgesIgnoringSafeArea(.all))
      .onAppear {
        runtimeWarn(
          """
          A "SwitchStore" at "\(self.fileID):\(self.line)" does not handle the current case. …

            Unhandled case:
              \(debugCaseOutput(self.store.wrappedValue.state.value))

          Make sure that you exhaustively provide a "CaseLet" view for each case in your state, \
          or provide a "Default" view at the end of the "SwitchStore".
          """,
          file: self.file,
          line: self.line
        )
      }
    #else
      return EmptyView()
    #endif
  }
}

private final class StoreObservableObject<State, Action>: ObservableObject {
  let wrappedValue: Store<State, Action>

  init(store: Store<State, Action>) {
    self.wrappedValue = store
  }
}

private func enumTag<Case>(_ `case`: Case) -> UInt32? {
  let metadataPtr = unsafeBitCast(type(of: `case`), to: UnsafeRawPointer.self)
  let kind = metadataPtr.load(as: Int.self)
  let isEnumOrOptional = kind == 0x201 || kind == 0x202
  guard isEnumOrOptional else { return nil }
  let vwtPtr = (metadataPtr - MemoryLayout<UnsafeRawPointer>.size).load(as: UnsafeRawPointer.self)
  let vwt = vwtPtr.load(as: EnumValueWitnessTable.self)
  return withUnsafePointer(to: `case`) { vwt.getEnumTag($0, metadataPtr) }
}

private struct EnumValueWitnessTable {
  let f1, f2, f3, f4, f5, f6, f7, f8: UnsafeRawPointer
  let f9, f10: Int
  let f11, f12: UInt32
  let getEnumTag: @convention(c) (UnsafeRawPointer, UnsafeRawPointer) -> UInt32
  let f13, f14: UnsafeRawPointer
}
