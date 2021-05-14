import SwiftUI

public struct SwitchStore<State, Action, Content>: View where Content: View {
  public let store: Store<State, Action>
  public let content: () -> Content

  public init<LocalState, LocalAction, LocalContent>(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping () -> Content
  )
  where
    Content == CaseStore<State, Action, LocalState, LocalAction, LocalContent>
  {
    self.store = store
    self.content = content
  }

  public init<S1, A1, C1, S2, A2, C2>(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping () -> Content
  )
  where
    Content == TupleView<(
      CaseStore<State, Action, S1, A1, C1>,
      CaseStore<State, Action, S2, A2, C2>
    )>
  {
    self.store = store
    self.content = content
  }

  public init<S1, A1, C1, S2, A2, C2, S3, A3, C3>(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping () -> Content
  )
  where
    Content == TupleView<(
      CaseStore<State, Action, S1, A1, C1>,
      CaseStore<State, Action, S2, A2, C2>,
      CaseStore<State, Action, S3, A3, C3>
    )>
  {
    self.store = store
    self.content = content
  }

  public var body: some View {
//    WithViewStore(self.store, removeDuplicates: { Tag($0) == Tag($1) }) { _ in
      self.content()
        .environmentObject(StoreObservableObject(store: self.store))
//    }
  }
}

private class StoreObservableObject<State, Action>: ObservableObject {
  let wrappedStore: Store<State, Action>

  init(store: Store<State, Action>) {
    self.wrappedStore = store
  }
}

public struct CaseStore<GlobalState, GlobalAction, LocalState, LocalAction, Content>: View
where
  Content: View
{
  @EnvironmentObject private var store: StoreObservableObject<GlobalState, GlobalAction>
  let toLocalState: CasePath<GlobalState, LocalState>
  let fromLocalAction: (LocalAction) -> GlobalAction
  let content: (Store<LocalState, LocalAction>) -> Content

  public init(
    state toLocalState: CasePath<GlobalState, LocalState>,
    action fromLocalAction: @escaping (LocalAction) -> GlobalAction,
    @ViewBuilder then content: @escaping (Store<LocalState, LocalAction>) -> Content
  ) {
    self.toLocalState = toLocalState
    self.fromLocalAction = fromLocalAction
    self.content = content
  }

  public var body: some View {
    IfLetStore(
      self.store.wrappedStore.scope(
        state: self.toLocalState.extract(from:),
        action: self.fromLocalAction
      ),
      then: self.content
    )
  }
}

func f() {
  struct LoggedInState: Equatable {}
  enum LoggedInAction: Equatable {}
  struct LoggedInView: View {
    let store: Store<LoggedInState, LoggedInAction>
    var body: some View { EmptyView() }
  }

  struct LoggedOutState: Equatable {}
  enum LoggedOutAction: Equatable {}
  struct LoggedOutView: View {
    let store: Store<LoggedInState, LoggedInAction>
    var body: some View { EmptyView() }
  }

  enum AppState: Equatable {
    case loggedIn(LoggedInState)
    case loggedOut(LoggedOutState)
  }
  enum AppAction: Equatable {
    case loggedIn(LoggedInAction)
    case loggedOut(LoggedOutAction)
  }
  struct AppView: View {
    let store: Store<AppState, AppAction>

    var body: some View {
      SwitchStore(self.store) {
        CaseStore(
          state: /AppState.loggedIn,
          action: AppAction.loggedIn,
          then: LoggedInView.init(store:)
        )
        CaseStore(
          state: /AppState.loggedIn,
          action: AppAction.loggedIn,
          then: LoggedInView.init(store:)
        )
      }

//      SwitchStore(self.store) {
//        CaseStore(
//          state: /AppState.loggedIn,
//          action: AppAction.loggedIn,
//          then: LoggedInView.init(store:)
//        )
//        CaseStore(
//          state: /AppState.loggedIn,
//          action: AppAction.loggedIn,
//          then: LoggedInView.init(store:)
//        )
//      }
//
//      SwitchStore(self.store) { route in
//        route.case(
//          state: /AppState.loggedIn,
//          action: AppAction.loggedIn,
//          then: LoggedInView.init(store:)
//        )
//        route.case(
//          state: /AppState.loggedIn,
//          action: AppAction.loggedIn,
//          then: LoggedInView.init(store:)
//        )
//      }
//
//      SwitchStore(self.store)
//        .case(
//          state: /AppState.loggedIn,
//          action: AppAction.loggedIn,
//          then: LoggedInView.init(store:)
//        )
//        .case(
//          state: /AppState.loggedIn,
//          action: AppAction.loggedIn,
//          then: LoggedInView.init(store:)
//        )
//      }
    }
  }
}

private struct EnumValueWitnessTable {
  let f1, f2, f3, f4, f5, f6, f7, f8: UnsafeRawPointer
  let size, stride: Int
  let flags, extraInhabitantCount: UInt32
  let getEnumTag: @convention(c) (_ value: UnsafeRawPointer, _ metadata: UnsafeRawPointer) -> UInt32
  let f9, f10: UnsafeRawPointer
}

struct Tag<Enum>: Equatable, Hashable {
  let rawValue: UInt32

  init?(_ `case`: Enum) {
    let enumType = type(of: `case`)
    let metadataPtr = unsafeBitCast(enumType, to: UnsafeRawPointer.self)
    let metadataKind = metadataPtr.load(as: Int.self)
    let isEnum = metadataKind == 0x201
    guard isEnum else { return nil }
    let vwtPtr = (metadataPtr - MemoryLayout<UnsafeRawPointer>.size).load(as: UnsafeRawPointer.self)
    let vwt = vwtPtr.load(as: EnumValueWitnessTable.self)
    self.rawValue = withUnsafePointer(to: `case`, { vwt.getEnumTag($0, metadataPtr) })
  }
}

