import ComposableArchitecture
import SwiftUI

struct FocusDemoState: Equatable {
  var focusedField: Field?

  enum Field: String, Hashable {
    case email, name, password
  }
}

extension Reducer {
  func focus<Focus>(
    state toFocusState: WritableKeyPath<State, Focus?>,
    action extractFocusAction: @escaping (Action) -> Focus?
  ) -> Self {
    Self { state, action, environment in
      guard case let .some(focus) = extractFocusAction(action)
      else { return .none }
      state[keyPath: toFocusState] = focus
      return .none
    }
    .combined(with: self)
  }
}

enum FocusDemoAction: Equatable {
  case focus(FocusDemoState.Field?)
}

let focusDemoReducer = Reducer<
  FocusDemoState,
  FocusDemoAction,
  Void
> { state, action, environment in
  switch action {
  case .focus:
    return .none
  }
}
  .focus(state: \.focusedField, action: /FocusDemoAction.focus)

struct FocusDemoView: View {
  let store: Store<FocusDemoState, FocusDemoAction>
  @ObservedObject var viewStore: ViewStore<FocusDemoState, FocusDemoAction>

  init(store: Store<FocusDemoState, FocusDemoAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store)
  }

  @FocusState var focus: FocusDemoState.Field?

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack {
        TextField("Email", text: .constant(""))
          .focused(self.$focus, equals: .email)
        
        TextField("Name", text: .constant(""))
          .focused(self.$focus, equals: .name)

        TextField("Password", text: .constant(""))
          .focused(self.$focus, equals: .password)

        Section {
          Button("Focus email") {
            viewStore.send(.focus(.email))
          }
          Button("Focus Name") {
            viewStore.send(.focus(.name))
          }
          Button("Focus Password") {
            viewStore.send(.focus(.password))
          }
          Button("Focus None") {
            viewStore.send(.focus(nil))
          }
        }

        Section {
          Text("Current focus: \(viewStore.focusedField?.rawValue ?? "None")")
        }
      }
      .focus(
        self.store.scope(state: \.focusedField, action: FocusDemoAction.focus),
        self.$focus
      )
    }
  }
}

extension View {
  func focus<Focus: Hashable>(
    _ store: Store<Focus?, Focus?>,
    _ focus: FocusState<Focus?>.Binding
  ) -> some View {
    let viewStore = ViewStore(store)
    return self
      .onChange(of: viewStore.state) { focus.wrappedValue = $0 }
      .onChange(of: focus.wrappedValue) { viewStore.send($0) }
  }
}

struct FocusDemoView_Previews: PreviewProvider {
  static var previews: some View {
    FocusDemoView(
      store: .init(
        initialState: .init(),
        reducer: focusDemoReducer,
        environment: ()
      )
    )
  }
}
