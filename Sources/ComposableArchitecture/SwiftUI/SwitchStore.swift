import SwiftUI

public struct SwitchStore<State, Action, Content>: View where Content: View {
  public let store: Store<State, Action>
  public let content: () -> Content

  public init<State1, Action1, Content1, DefaultContent>(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping () -> TupleView<(
      CaseLet<State, Action, State1, Action1, Content1>,
      Default<DefaultContent>
    )>
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
    @ViewBuilder content: @escaping ()
      -> CaseLet<State, Action, LocalState, LocalAction, LocalContent>,
    file: StaticString = #file,
    line: UInt = #line
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        CaseLet<State, Action, LocalState, LocalAction, LocalContent>,
        Default<AssertionView>
      >
    >
  {
    self.init(store) {
      content()
      Default { AssertionView(file: file, line: line) }
    }
  }

  public init<State1, Action1, Content1, State2, Action2, Content2, DefaultContent>(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping () -> TupleView<(
      CaseLet<State, Action, State1, Action1, Content1>,
      CaseLet<State, Action, State2, Action2, Content2>,
      Default<DefaultContent>
    )>
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        TupleView<(
          CaseLet<State, Action, State1, Action1, Content1>,
          CaseLet<State, Action, State2, Action2, Content2>
        )>,
        Default<DefaultContent>
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

  public init<State1, Action1, Content1, State2, Action2, Content2>(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping () -> TupleView<(
      CaseLet<State, Action, State1, Action1, Content1>,
      CaseLet<State, Action, State2, Action2, Content2>
    )>,
    file: StaticString = #file,
    line: UInt = #line
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        TupleView<(
          CaseLet<State, Action, State1, Action1, Content1>,
          CaseLet<State, Action, State2, Action2, Content2>
        )>,
        Default<AssertionView>
      >
    >
  {
    self.init(store) {
      let content = content()
      content.value.0
      content.value.1
      Default { AssertionView(file: file, line: line) }
    }
  }

  public init<
    State1, Action1, Content1,
    State2, Action2, Content2,
    State3, Action3, Content3,
    DefaultContent
  >(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping () -> TupleView<(
      CaseLet<State, Action, State1, Action1, Content1>,
      CaseLet<State, Action, State2, Action2, Content2>,
      CaseLet<State, Action, State3, Action3, Content3>,
      Default<DefaultContent>
    )>
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        TupleView<(
          CaseLet<State, Action, State1, Action1, Content1>,
          CaseLet<State, Action, State2, Action2, Content2>,
          CaseLet<State, Action, State3, Action3, Content3>
        )>,
        Default<DefaultContent>
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

  public init<State1, Action1, Content1, State2, Action2, Content2, State3, Action3, Content3>(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping () -> TupleView<(
      CaseLet<State, Action, State1, Action1, Content1>,
      CaseLet<State, Action, State2, Action2, Content2>,
      CaseLet<State, Action, State3, Action3, Content3>
    )>,
    file: StaticString = #file,
    line: UInt = #line
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        TupleView<(
          CaseLet<State, Action, State1, Action1, Content1>,
          CaseLet<State, Action, State2, Action2, Content2>,
          CaseLet<State, Action, State3, Action3, Content3>
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
      Default { AssertionView(file: file, line: line) }
    }
  }

  public var body: some View {
    self.content()
      .environmentObject(StoreObservableObject(store: self.store))
  }
}

public struct CaseLet<GlobalState, GlobalAction, LocalState, LocalAction, Content>: View
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

public struct AssertionView: View {
  public init(file: StaticString = #file, line: UInt = #line) {
    fputs(
      """
      Warning: SwitchStore must be exhaustive @ \(file):\(line)

      A SwitchStore was used in file \(file) at line \(line) without exhaustively handling every
      case with a CaseLet view. Make sure that you provide a CaseLet for each case in your enum,
      or provide a Default view at the end of the SwitchStore's body.
      """,
      stderr
    )
    raise(SIGTRAP)
  }

  public var body: some View {
    return EmptyView()
  }
}

public struct Default<Content>: View where Content: View {
  private let content: () -> Content

  public init(
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.content = content
  }

  public var body: some View {
    self.content()
  }
}

private class StoreObservableObject<State, Action>: ObservableObject {
  let wrappedStore: Store<State, Action>

  init(store: Store<State, Action>) {
    self.wrappedStore = store
  }
}

private struct EnumValueWitnessTable {
  let f1, f2, f3, f4, f5, f6, f7, f8: UnsafeRawPointer
  let size, stride: Int
  let flags, extraInhabitantCount: UInt32
  let getEnumTag: @convention(c) (_ value: UnsafeRawPointer, _ metadata: UnsafeRawPointer) -> UInt32
  let f9, f10: UnsafeRawPointer
}

private struct Tag<Enum>: Equatable, Hashable {
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
