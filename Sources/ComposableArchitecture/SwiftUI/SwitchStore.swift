import SwiftUI

public struct SwitchStore<State, Action, Content>: View where Content: View {
  public let store: Store<State, Action>
  public let content: () -> Content

  public var body: some View {
    self.content()
      .environmentObject(StoreObservableObject(store: self.store))
  }
}

public struct CaseLet<GlobalState, GlobalAction, LocalState, LocalAction, Content>: View
where Content: View {
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
      self.store.wrappedValue.scope(
        state: self.toLocalState.extract(from:),
        action: self.fromLocalAction
      ),
      then: self.content
    )
  }
}

public struct Default<Content>: View where Content: View {
  private let content: () -> Content

  public init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }

  public var body: some View {
    self.content()
  }
}

extension SwitchStore {
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
    self.init(store: store) {
      WithViewStore(store, removeDuplicates: { Tag($0) == Tag($1) }) { viewStore in
        let content = content().value
        switch viewStore.state {
        case content.0.toLocalState:
          content.0
        default:
          content.1
        }
      }
    }
  }

  public init<State1, Action1, Content1>(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping ()
      -> CaseLet<State, Action, State1, Action1, Content1>,
    file: StaticString = #fileID,
    line: UInt = #line
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        CaseLet<State, Action, State1, Action1, Content1>,
        Default<_ExhaustivityCheckView>
      >
    >
  {
    self.init(store) {
      content()
      Default { _ExhaustivityCheckView(file: file, line: line) }
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
        _ConditionalContent<
          CaseLet<State, Action, State1, Action1, Content1>,
          CaseLet<State, Action, State2, Action2, Content2>>,
        Default<DefaultContent>
      >
    >
  {
    self.store = store
    self.content = {
      WithViewStore(store, removeDuplicates: { Tag($0) == Tag($1) }) { viewStore in
        let content = content().value
        switch viewStore.state {
        case content.0.toLocalState:
          content.0
        case content.1.toLocalState:
          content.1
        default:
          content.2
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
    file: StaticString = #fileID,
    line: UInt = #line
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        _ConditionalContent<
          CaseLet<State, Action, State1, Action1, Content1>,
          CaseLet<State, Action, State2, Action2, Content2>>,
        Default<_ExhaustivityCheckView>
      >
    >
  {
    self.init(store) {
      let content = content()
      content.value.0
      content.value.1
      Default { _ExhaustivityCheckView(file: file, line: line) }
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
    self.store = store
    self.content = {
      WithViewStore(store, removeDuplicates: { Tag($0) == Tag($1) }) { viewStore in
        let content = content().value
        switch viewStore.state {
        case content.0.toLocalState:
          content.0
        case content.1.toLocalState:
          content.1
        case content.2.toLocalState:
          content.2
        default:
          content.3
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
    file: StaticString = #fileID,
    line: UInt = #line
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
          Default<_ExhaustivityCheckView>
        >
      >
    >
  {
    self.init(store) {
      let content = content()
      content.value.0
      content.value.1
      content.value.2
      Default { _ExhaustivityCheckView(file: file, line: line) }
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
    @ViewBuilder content: @escaping () -> TupleView<(
      CaseLet<State, Action, State1, Action1, Content1>,
      CaseLet<State, Action, State2, Action2, Content2>,
      CaseLet<State, Action, State3, Action3, Content3>,
      CaseLet<State, Action, State4, Action4, Content4>,
      Default<DefaultContent>
    )>
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
    self.store = store
    self.content = {
      WithViewStore(store, removeDuplicates: { Tag($0) == Tag($1) }) { viewStore in
        let content = content().value
        switch viewStore.state {
        case content.0.toLocalState:
          content.0
        case content.1.toLocalState:
          content.1
        case content.2.toLocalState:
          content.2
        case content.3.toLocalState:
          content.3
        default:
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
    @ViewBuilder content: @escaping () -> TupleView<(
      CaseLet<State, Action, State1, Action1, Content1>,
      CaseLet<State, Action, State2, Action2, Content2>,
      CaseLet<State, Action, State3, Action3, Content3>,
      CaseLet<State, Action, State4, Action4, Content4>
    )>,
    file: StaticString = #fileID,
    line: UInt = #line
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
        Default<_ExhaustivityCheckView>
      >
    >
  {
    self.init(store) {
      let content = content()
      content.value.0
      content.value.1
      content.value.2
      content.value.3
      Default { _ExhaustivityCheckView(file: file, line: line) }
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
    @ViewBuilder content: @escaping () -> TupleView<(
      CaseLet<State, Action, State1, Action1, Content1>,
      CaseLet<State, Action, State2, Action2, Content2>,
      CaseLet<State, Action, State3, Action3, Content3>,
      CaseLet<State, Action, State4, Action4, Content4>,
      CaseLet<State, Action, State5, Action5, Content5>,
      Default<DefaultContent>
    )>
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
    self.store = store
    self.content = {
      WithViewStore(store, removeDuplicates: { Tag($0) == Tag($1) }) { viewStore in
        let content = content().value
        switch viewStore.state {
        case content.0.toLocalState:
          content.0
        case content.1.toLocalState:
          content.1
        case content.2.toLocalState:
          content.2
        case content.3.toLocalState:
          content.3
        case content.4.toLocalState:
          content.4
        default:
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
    @ViewBuilder content: @escaping () -> TupleView<(
      CaseLet<State, Action, State1, Action1, Content1>,
      CaseLet<State, Action, State2, Action2, Content2>,
      CaseLet<State, Action, State3, Action3, Content3>,
      CaseLet<State, Action, State4, Action4, Content4>,
      CaseLet<State, Action, State5, Action5, Content5>
    )>,
    file: StaticString = #fileID,
    line: UInt = #line
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
          Default<_ExhaustivityCheckView>
        >
      >
    >
  {
    self.init(store) {
      let content = content()
      content.value.0
      content.value.1
      content.value.2
      content.value.3
      content.value.4
      Default { _ExhaustivityCheckView(file: file, line: line) }
    }
  }
}

public struct _ExhaustivityCheckView: View {
  let message: String
  let file: StaticString
  let line: UInt

  init(
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.message = """
      Warning: SwitchStore.body@\(file):\(line)

      A "SwitchStore" did not exhaustively handle every case with a "CaseLet" view. Make sure that \
      you provide a "CaseLet" for each case in your enum, or provide a "Default" view at the end \
      of the "SwitchStore".
      """
    self.file = file
    self.line = line
  }

  public var body: some View {
    #if DEBUG
      VStack(spacing: 17) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.largeTitle)

        Text(self.message)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .foregroundColor(.white)
      .padding()
      .background(Color.red.edgesIgnoringSafeArea(.all))
      .onAppear {
        let isDebuggerAttached: Bool = {
            var debuggerIsAttached = false

            var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
            var info: kinfo_proc = kinfo_proc()
            var info_size = MemoryLayout<kinfo_proc>.size

            let success = name.withUnsafeMutableBytes { (nameBytePtr: UnsafeMutableRawBufferPointer) -> Bool in
                guard let nameBytesBlindMemory = nameBytePtr.bindMemory(to: Int32.self).baseAddress else { return false }
                return -1 != sysctl(nameBytesBlindMemory, 4, &info, &info_size, nil, 0)
            }

            if !success {
                debuggerIsAttached = false
            }

            if !debuggerIsAttached && (info.kp_proc.p_flag & P_TRACED) != 0 {
                debuggerIsAttached = true
            }

            return debuggerIsAttached
        }()

        fputs(
          """
          ---
          \(self.message)
          ---

          """,
          stderr
        )
        if isDebuggerAttached {
          raise(SIGTRAP)
        }
      }
    #endif
  }
}

private class StoreObservableObject<State, Action>: ObservableObject {
  let wrappedValue: Store<State, Action>

  init(store: Store<State, Action>) {
    self.wrappedValue = store
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
