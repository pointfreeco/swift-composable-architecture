import SwiftUI

public struct SwitchStore<State, Action, Content>: View where Content: View {
  public let store: Store<State, Action>
  public let content: () -> Content

  public init<S1, A1, C1, D>(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping () -> TupleView<(
      Case<State, Action, S1, A1, C1>,
      Default<D>
    )>
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        Case<State, Action, S1, A1, C1>,
        Default<D>
      >
    >
  {
    self.store = store
    self.content = {
      WithViewStore(store, removeDuplicates: { Tag($0) == Tag($1) }) { viewStore in
        let content = content()
        if content.value.0.toLocalState.extract(from: viewStore.state) != nil {
          content.value.0
        } else {
          content.value.1
        }
      }
    }
  }

  public init<LocalState, LocalAction, LocalContent>(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping () -> Case<State, Action, LocalState, LocalAction, LocalContent>
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        Case<State, Action, LocalState, LocalAction, LocalContent>,
        Default<AssertionView>
      >
    >
  {
    self.init(store) {
      content()
      Default { AssertionView() }
    }
  }

  public init<S1, A1, C1, S2, A2, C2, D>(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping () -> TupleView<(
      Case<State, Action, S1, A1, C1>,
      Case<State, Action, S2, A2, C2>,
      Default<D>
    )>
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        TupleView<(
          Case<State, Action, S1, A1, C1>,
          Case<State, Action, S2, A2, C2>
        )>,
        Default<D>
      >
    >
  {
    self.store = store
    self.content = {
      WithViewStore(store, removeDuplicates: { Tag($0) == Tag($1) }) { viewStore in
        let content = content()
        if
          content.value.0.toLocalState.extract(from: viewStore.state) != nil
            || content.value.1.toLocalState.extract(from: viewStore.state) != nil
        {
          content.value.0
          content.value.1
        } else {
          content.value.2
        }
      }
    }
  }

  public init<S1, A1, C1, S2, A2, C2>(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping () -> TupleView<(
      Case<State, Action, S1, A1, C1>,
      Case<State, Action, S2, A2, C2>
    )>
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        TupleView<(
          Case<State, Action, S1, A1, C1>,
          Case<State, Action, S2, A2, C2>
        )>,
        Default<AssertionView>
      >
    >
  {
    self.init(store) {
      let content = content()
      content.value.0
      content.value.1
      Default { AssertionView() }
    }
  }

  public init<S1, A1, C1, S2, A2, C2, S3, A3, C3, D>(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping () -> TupleView<(
      Case<State, Action, S1, A1, C1>,
      Case<State, Action, S2, A2, C2>,
      Case<State, Action, S3, A3, C3>,
      Default<D>
    )>
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        TupleView<(
          Case<State, Action, S1, A1, C1>,
          Case<State, Action, S2, A2, C2>,
          Case<State, Action, S3, A3, C3>
        )>,
        Default<D>
      >
    >
  {
    self.store = store
    self.content = {
      WithViewStore(store, removeDuplicates: { Tag($0) == Tag($1) }) { viewStore in
        let content = content()
        if
          content.value.0.toLocalState.extract(from: viewStore.state) != nil
            || content.value.1.toLocalState.extract(from: viewStore.state) != nil
            || content.value.2.toLocalState.extract(from: viewStore.state) != nil
        {
          content.value.0
          content.value.1
          content.value.2
        } else {
          content.value.3
        }
      }
    }
  }

  public init<S1, A1, C1, S2, A2, C2, S3, A3, C3>(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping () -> TupleView<(
      Case<State, Action, S1, A1, C1>,
      Case<State, Action, S2, A2, C2>,
      Case<State, Action, S3, A3, C3>
    )>
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        TupleView<(
          Case<State, Action, S1, A1, C1>,
          Case<State, Action, S2, A2, C2>,
          Case<State, Action, S3, A3, C3>
        )>,
        Default<AssertionView>
      >
    >
  {
    self.init(store) {
      let content = content()
      content.value.0
      content.value.1
      content.value.2
      Default { AssertionView() }
    }
  }

  public var body: some View {
    self.content()
      .environmentObject(StoreObservableObject(store: self.store))
  }
}

private class StoreObservableObject<State, Action>: ObservableObject {
  let wrappedStore: Store<State, Action>

  init(store: Store<State, Action>) {
    self.wrappedStore = store
  }
}

public struct Case<GlobalState, GlobalAction, LocalState, LocalAction, Content>: View
where
  Content: View
{
  @EnvironmentObject private var store: StoreObservableObject<GlobalState, GlobalAction>
  let toLocalState: CasePath<GlobalState, LocalState>
  let fromLocalAction: (LocalAction) -> GlobalAction
  let content: (Store<LocalState, LocalAction>) -> Content

  public init(
    `let` toLocalState: CasePath<GlobalState, LocalState>,
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

public struct AssertionView: View {
  init(file: StaticString = #file, line: UInt = #line) {
    assertionFailure(file: file, line: line)
  }

  public var body: some View {
    return EmptyView()
  }
}

public struct Default<Content>: View where Content: View {
  let content: () -> Content

  public init(
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.content = content
  }

  public var body: some View {
    self.content()
  }
}

private struct EnumValueWitnessTable {
  let f1, f2, f3, f4, f5, f6, f7, f8: UnsafeRawPointer
  let size, stride: Int
  let flags, extraInhabitantCount: UInt32
  let getEnumTag: @convention(c) (_ value: UnsafeRawPointer, _ metadata: UnsafeRawPointer) -> UInt32
  let f9, f10: UnsafeRawPointer
}

public struct Tag<Enum>: Equatable, Hashable {
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
