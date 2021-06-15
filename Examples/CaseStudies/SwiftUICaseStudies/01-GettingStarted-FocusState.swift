import ComposableArchitecture
import SwiftUI

struct FocusDemoState: Equatable {
  var focusedField: Field?

  enum Field: String, Hashable {
    case email, name, password
  }
}

enum FocusDemoAction {
  case binding(BindingAction<FocusDemoState>)
  case focusEmailButtonTapped
  case focusNameButtonTapped
  case focusNoneButtonTapped
  case focusPasswordButtonTapped
}

let focusDemoReducer = Reducer<
  FocusDemoState,
  FocusDemoAction,
  Void
> { state, action, environment in
  switch action {
  case .binding:
    return .none

  case .focusEmailButtonTapped:
    state.focusedField = .email
    return .none

  case .focusNameButtonTapped:
    state.focusedField = .name
    return .none

  case .focusNoneButtonTapped:
    state.focusedField = nil
    return .none

  case .focusPasswordButtonTapped:
    state.focusedField = .password
    return .none
  }
}
  .binding(action: /FocusDemoAction.binding)

struct FocusDemoView: View {
  let store: Store<FocusDemoState, FocusDemoAction>
  @ObservedObject var viewStore: ViewStore<FocusDemoState, FocusDemoAction>

  init(store: Store<FocusDemoState, FocusDemoAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store)
  }

  @FocusState var focus: FocusDemoState.Field?

  var body: some View {
//    WithViewStore(self.store) { viewStore in
      Form {
        TextField("Email", text: .constant(""))
          .focused(self.$focus, equals: .email)
        
        TextField("Name", text: .constant(""))
          .focused(self.$focus, equals: .name)

        TextField("Password", text: .constant(""))
          .focused(self.$focus, equals: .password)

        Section {
          Button("Focus email") {
            self.focus = .email
//            viewStore.send(.focusEmailButtonTapped)
          }
          Button("Focus Name") {
//            viewStore.send(.focusEmailButtonTapped)
          }
          Button("Focus Password") {
//            viewStore.send(.focusPasswordButtonTapped)
          }
          Button("Focus None") {
//            viewStore.send(.focusNoneButtonTapped)
          }
        }

        Section {
          Text("Current focus: \(viewStore.focusedField?.rawValue ?? "None")")
        }
      }
      .onChange(of: viewStore.focusedField) {
        self.focus = $0
      }
      .onChange(of: self.focus) {
        viewStore.send(.binding(.set(\.focusedField, $0)))
      }
//    }
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
