import ComposableArchitecture
import SwiftUI

struct FocusDemoState: Equatable {
  var focusedField: Field?

  enum Field: String, Hashable {
    case email, name, password
  }
}

enum FocusAction<Focus> {
  case set(Focus?)
}
extension FocusAction: Equatable where Focus: Equatable {}
extension FocusAction: Hashable where Focus: Hashable {}

extension Reducer {
  func focus<Focus>(
    state toFocusState: WritableKeyPath<State, Focus?>,
    action extractFocusAction: @escaping (Action) -> FocusAction<Focus>?
  ) -> Self {
    Self { state, action, environment in
      guard case let .some(.set(focus)) = extractFocusAction(action)
      else { return .none }
      state[keyPath: toFocusState] = focus
      return .none
    }
    .combined(with: self)
  }
}

enum FocusDemoAction: Equatable {
  case focus(FocusAction<FocusDemoState.Field>)
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
  case .focus:
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
            viewStore.send(.focusEmailButtonTapped)
          }
          Button("Focus Name") {
            viewStore.send(.focusNameButtonTapped)
          }
          Button("Focus Password") {
            viewStore.send(.focusPasswordButtonTapped)
          }
          Button("Focus None") {
            viewStore.send(.focusNoneButtonTapped)
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
        viewStore.send(.focus(.set($0)))
      }
    }
  }
}

//extension View {
//  func focus<Focus: Hashable>(_ focus: Focus?, )
//}

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
