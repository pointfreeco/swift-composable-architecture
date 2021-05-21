import AppCore
import ComposableArchitecture
import LoginSwiftUI
import NewGameSwiftUI
import SwiftUI
import TicTacToeCommon

//extension CasePath {
//  func eraseToAnyCasePath() -> CasePath<Root, Any> {
//    .init(
//      embed: { self.embed($0 as! Value) },
//      extract: { self.extract(from: $0) }
//    )
//  }
//}
//
//public struct Case<State, Action> {
//  let state: CasePath<State, Any>
//}
//
//@resultBuilder
//public struct CaseBuilder {
//  public static func buildBlock(_ components: Case...) -> Case {
//    components[0]
//  }
//}

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

public struct _AssertionView: View {
  init(file: StaticString = #file, line: UInt = #line) {
    assertionFailure(file: file, line: line)
  }

  public var body: some View {
    return EmptyView()
  }
}

struct _SwitchStore<State, Action>: View {
  let store: Store<State, Action>
  let content: [((State) -> Bool, AnyView)]
  let `default`: () -> AnyView

  init(
    store: Store<State, Action>,
    content: [((State) -> Bool, AnyView)] = [],
    default: @escaping () -> AnyView = { AnyView(_AssertionView()) }
  ) {
    self.store = store
    self.content = content
    self.default = `default`
  }

  var body: some View {
    WithViewStore(self.store, removeDuplicates: { Tag($0) == Tag($1) }) { viewStore -> AnyView in
      for content in self.content {
        if content.0(viewStore.state) {
          return content.1
        }
      }
      return self.default()
    }

//    WithViewStore(self.store.scope(state: Tag.init)) { viewStore in
//      if let tag = viewStore.state, let view = self.content[tag] {
//        view
//      } else {
//        AssertionView()
//      }
//    }
  }

  func `case`<LocalState, LocalAction, LocalView>(
    state: CasePath<State, LocalState>,
    action: @escaping (LocalAction) -> Action,
    _ content: @escaping (Store<LocalState, LocalAction>) -> LocalView
  ) -> Self
  where LocalView: View {
    return _SwitchStore(
      store: self.store,
      content: self.content + [(
        { state.extract(from: $0) != nil },
        AnyView(
          IfLetStore(
            self.store.scope(
              state: { state.extract(from: $0) },
              action: action
            ),
            then: content
          )
        )
      )]
    )
  }

  func `default`<V: View>(
    @ViewBuilder _ content: @escaping () -> V
  ) -> some View {
    AnyView(
      _SwitchStore(
        store: self.store,
        content: self.content,
        default: { AnyView(content()) }
      )
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
      Case(let: /AppState.login, action: AppAction.login) { store in
        NavigationView {
          LoginView(store: store)
        }
      }
      Default {
        Text("Fallthrough")
      }
//      CaseStore(state: /AppState.newGame, action: AppAction.newGame) { store in
//        NavigationView {
//          NewGameView(store: store)
//        }
//      }
    }
//    _SwitchStore(store: self.store)
//      .case(state: /AppState.login, action: AppAction.login) { store in
//        NavigationView {
//          LoginView(store: store)
//        }
//      }
////      .case(state: /AppState.newGame, action: AppAction.newGame) { store in
////        NavigationView {
////          NewGameView(store: store)
////        }
////      }
//      .default {
//        Text("Ooops")
//      }

    /*

     SwitchStore(self.store)
       .case(/AppState.login, action: AppAction.login) { store in

       }

     */
  }
}
