import AppCore
import ComposableArchitecture
import LoginSwiftUI
import NewGameSwiftUI
import SwiftUI
import TicTacToeCommon

public struct AppView: View {
  let store: Store<AppState, AppAction>

  public init(store: Store<AppState, AppAction>) {
    self.store = store
  }

  public var body: some View {
    _SwitchStore(self.store) {
      CaseLet_(state: /AppState.login, action: AppAction.login) { loginStore in
        NavigationView {
          LoginView(store: loginStore)
        }
        .navigationViewStyle(StackNavigationViewStyle())
      }

      CaseLet_(state: /AppState.newGame, action: AppAction.newGame) { newGame in
        NavigationView {
          NewGameView(store: newGame)
        }
        .navigationViewStyle(StackNavigationViewStyle())
      }
    }
  }
}

struct CaseLet_<GlobalState, GlobalAction, State, Action, Content: View>: View {
  let state: CasePath<GlobalState, State>
  let action: (Action) -> GlobalAction
  @EnvironmentObject private var storeWrapper: StoreWrapper<GlobalState, GlobalAction>
  @ViewBuilder let content: (Store<State, Action>) -> Content

  var body: some View {
    IfLetStore(
      self.storeWrapper.store.scope(state: state.extract(from:), action: action),
      then: self.content
    )
  }
}

private class StoreWrapper<State, Action>: ObservableObject {
  let store: Store<State, Action>
  init(_ store: Store<State, Action>) {
    self.store = store
  }
}

public struct _SwitchStore<State: Equatable, Action, Content>: View where Content: View {
  public let store: Store<State, Action>
  @ViewBuilder public let content: () -> Content

  init<State1, Action1, State2, Action2, Content1, Content2>(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping () -> TupleView<(
      CaseLet_<State, Action, State1, Action1, Content1>,
      CaseLet_<State, Action, State2, Action2, Content2>
    )>
  )
  where
    Content == WithViewStore<
      State,
      Action,
      _ConditionalContent<
        _ConditionalContent<
          CaseLet_<State, Action, State1, Action1, Content1>,
          CaseLet_<State, Action, State2, Action2, Content2>
        >,
        BreakpointView
      >
    >
  {
    self.store = store
    self.content = {
      let cases = content().value
      return WithViewStore(store, removeDuplicates: { enumTag($0) == enumTag($1) }) { viewStore in
        switch viewStore.state {
        case cases.0.state:
          cases.0
        case cases.1.state:
          cases.1
        default:
          BreakpointView()
        }
      }
    }
  }

  public var body: some View {
    self.content()
      .environmentObject(StoreWrapper(self.store))
  }
}


struct BreakpointView: View {
  init() {
    fputs(
      """
      ⚠️ Warning: SwitchStore must be exhaustive.

      A SwitchStore was used without exhaustively handling every \
      case with a CaseLet view. Make sure that you provide a \
      CaseLet for each case in your enum.
      """,
      stderr
    )
    raise(SIGTRAP)
  }

  var body: some View {
    #if DEBUG
    Text(
      """
      ⚠️  Warning: SwitchStore must be exhaustive.

      A SwitchStore was used without exhaustively handling every \
      case with a CaseLet view. Make sure that you provide a \
      CaseLet for each case in your enum.
      """
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundColor(.white)
    .background(Color.red)
    #endif
  }
}

private struct EnumValueWitnessTable {
  let f1, f2, f3, f4, f5, f6, f7, f8: UnsafeRawPointer
  let size, stride: Int
  let flags, extraInhabitantCount: UInt32
  let getEnumTag: @convention(c) (_ value: UnsafeRawPointer, _ metadata: UnsafeRawPointer) -> UInt32
  let f9, f10: UnsafeRawPointer
}

func enumTag<Enum>(_ `case`: Enum) -> UInt32? {
  let enumType = type(of: `case`)
  let metadataPtr = unsafeBitCast(enumType, to: UnsafeRawPointer.self)
  let metadataKind = metadataPtr.load(as: Int.self)
  let isEnum = metadataKind == 0x201
  guard isEnum else { return nil }
  let vwtPtr = (metadataPtr - MemoryLayout<UnsafeRawPointer>.size).load(as: UnsafeRawPointer.self)
  let vwt = vwtPtr.load(as: EnumValueWitnessTable.self)
  return withUnsafePointer(to: `case`, { vwt.getEnumTag($0, metadataPtr) })
}
