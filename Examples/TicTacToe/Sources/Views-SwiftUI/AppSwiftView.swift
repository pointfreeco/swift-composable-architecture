import AppCore
import ComposableArchitecture
import LoginSwiftUI
import NewGameSwiftUI
import SwiftUI
import TicTacToeCommon

let tmp = Group {
  Text("")
  Text("")
  Text("")
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
      ⚠️ Warning: SwitchStore must be exhaustive.

      A SwitchStore was used without exhaustively handling every \
      case with a CaseLet view. Make sure that you provide a \
      CaseLet for each case in your enum.
      """
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundColor(.white)
    .background(Color.red.ignoresSafeArea())
    #endif
  }
}


struct SwitchStore<State, Action, Content>: View where Content: View {
  let store: Store<State, Action>
  let content: () -> Content
  
  init<State1, Action1, State2, Action2, Content1, Content2>(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping () -> TupleView<(
      CaseLet<State, Action, State1, Action1, Content1>,
      CaseLet<State, Action, State2, Action2, Content2>
    )>
  )
  where Content == WithViewStore<
    State,
    Action,
    _ConditionalContent<
      _ConditionalContent<
        CaseLet<State, Action, State1, Action1, Content1>,
        CaseLet<State, Action, State2, Action2, Content2>
      >,
      BreakpointView
    >
  >
  {
    self.store = store
    self.content = {
      WithViewStore(store, removeDuplicates: { enumTag($0) == enumTag($1) }) { viewStore in
        let (case1, case2) = content().value
        switch viewStore.state {
        case case1.state:
          case1
        case case2.state:
          case2
        default:
          BreakpointView()
        }
      }
      .debug("Case changed")
    }
  }
  
  var body: some View {
    self.content()
      .environmentObject(StoreWrapper(store: self.store))
  }
}


private struct EnumValueWitnessTable {
  let f1, f2, f3, f4, f5, f6, f7, f8: UnsafeRawPointer
  let size, stride: Int
  let flags, extraInhabitantCount: UInt32
  let getEnumTag: @convention(c) (_ value: UnsafeRawPointer, _ metadata: UnsafeRawPointer) -> UInt32
  let f9, f10: UnsafeRawPointer
}

private func enumTag<Enum>(_ `case`: Enum) -> UInt32? {
  let enumType = type(of: `case`)
  let metadataPtr = unsafeBitCast(enumType, to: UnsafeRawPointer.self)
  let metadataKind = metadataPtr.load(as: Int.self)
  let isEnum = metadataKind == 0x201
  guard isEnum else { return nil }
  let vwtPtr = (metadataPtr - MemoryLayout<UnsafeRawPointer>.size).load(as: UnsafeRawPointer.self)
  let vwt = vwtPtr.load(as: EnumValueWitnessTable.self)
  return withUnsafePointer(to: `case`, { vwt.getEnumTag($0, metadataPtr) })
}


private class StoreWrapper<State, Action>: ObservableObject {
  let store: Store<State, Action>
  init(store: Store<State, Action>) {
    self.store = store
  }
}

struct CaseLet<GlobalState, GlobalAction, LocalState, LocalAction, Content>: View
where Content: View {
  @EnvironmentObject private var storeWrapper: StoreWrapper<GlobalState, GlobalAction>
  let state: CasePath<GlobalState, LocalState>
  let action: (LocalAction) -> GlobalAction
  @ViewBuilder let content: (Store<LocalState, LocalAction>) -> Content
  
  var body: some View {
    IfLetStore(
      self.storeWrapper.store.scope(state: state.extract(from:), action: action),
      then: self.content
    )
  }
}

public struct AppView: View {
  let store: Store<AppState, AppAction>

  public init(store: Store<AppState, AppAction>) {
    self.store = store
  }

  @ViewBuilder public var body: some View {
    SwitchStore(self.store) {
      CaseLet(state: /AppState.login, action: AppAction.login) { loginStore in
        NavigationView {
          LoginView(store: loginStore)
        }
        .navigationViewStyle(StackNavigationViewStyle())
      }
      CaseLet(state: /AppState.newGame, action: AppAction.newGame) { newGameStore in
        NavigationView {
          NewGameView(store: newGameStore)
        }
        .navigationViewStyle(StackNavigationViewStyle())
      }
    }
    
//    SwitchStore(self.store) {
//      CaseLet(state: /AppState.login, action: AppAction.login) { loginStore in
//        NavigationView {
//          LoginView(store: loginStore)
//        }
//        .navigationViewStyle(StackNavigationViewStyle())
//      }
//      CaseLet(state: /AppState.newGame, action: AppAction.newGame) { newGameStore in
//        NavigationView {
//          NewGameView(store: newGameStore)
//        }
//        .navigationViewStyle(StackNavigationViewStyle())
//      }
//    }
    
//    IfLetStore(
//      self.store.scope(
//        state: /AppState.login,
//        action: AppAction.login
//      )
//    ) { store in
//      NavigationView {
//        LoginView(store: store)
//      }
//      .navigationViewStyle(StackNavigationViewStyle())
//    }
//
//    IfLetStore(
//      self.store.scope(
//        state: /AppState.newGame,
//        action: AppAction.newGame
//      )
//    ) { store in
//      NavigationView {
//        NewGameView(store: store)
//      }
//      .navigationViewStyle(StackNavigationViewStyle())
//    }
  }
}
