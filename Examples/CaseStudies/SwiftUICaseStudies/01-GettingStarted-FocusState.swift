import ComposableArchitecture
import SwiftUI

struct FocusDemoState: Equatable {
  var focusedField: Field?

  enum Field: String, Hashable {
    case email, name, password
  }
}

enum FocusDemoAction: Equatable {
  case binding(BindingAction<FocusDemoState>)
  case focus(FocusDemoState.Field?)
}

let focusDemoReducer = Reducer<
  FocusDemoState,
  FocusDemoAction,
  Void
> { state, action, environment in
  switch action {
  case .binding:
    return .none
  case let .focus(focus):
    state.focusedField = focus
    return .none
  }
}
  .binding(action: /FocusDemoAction.binding)

struct FocusDemoView: View {
  let store: Store<FocusDemoState, FocusDemoAction>
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
//      .synchronize(
//        viewStore.binding(get: \.focusedField, send: <#T##(LocalState) -> Action#>)
//      )
    }
//    .synchronize(
//      self.store.scope(state: \.focusedField, action: FocusDemoAction.focus),
//      with: self.$focus
//    )
  }
}

extension View {
  func synchronize<Value: Hashable>(
    _ store: Store<Value, Value>,
    with binding: FocusState<Value>.Binding
  ) -> some View {
    self.synchronize(
      store,
      with: Binding(
        get: { binding.wrappedValue },
        set: { binding.wrappedValue = $0 }
      )
    )
  }

  func synchronize<Value: Equatable>(
    _ store: Store<Value, Value>,
    with binding: Binding<Value>
  ) -> some View {
    WithViewStore(store) { viewStore in
      self
        .onChange(of: viewStore.state) { binding.wrappedValue = $0 }
        .onChange(of: binding.wrappedValue) { viewStore.send($0) }
    }
  }

  func synchronize<Value: Equatable>(
    _ a: Binding<Value>,
    with b: Binding<Value>
  ) -> some View {
    self
      .onChange(of: a.wrappedValue) { a.wrappedValue = $0 }
      .onChange(of: b.wrappedValue) { b.wrappedValue = $0 }
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
