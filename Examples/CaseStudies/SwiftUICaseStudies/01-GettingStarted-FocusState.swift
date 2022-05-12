#if compiler(>=5.5)
  import ComposableArchitecture
  import SwiftUI

  private let readMe = """
    This demonstrates how to make use of SwiftUI's `@FocusState` in the Composable Architecture. \
    If you tap the "Sign in" button while a field is empty, the focus will be changed to that field.
    """

  struct FocusDemoState: Equatable {
    @BindableState var focusedField: Field? = nil
    @BindableState var password: String = ""
    @BindableState var username: String = ""

    enum Field: String, Hashable {
      case username, password
    }
  }

  enum FocusDemoAction: BindableAction, Equatable {
    case binding(BindingAction<FocusDemoState>)
    case signInButtonTapped
  }

  struct FocusDemoEnvironment {}

  let focusDemoReducer = Reducer<
    FocusDemoState,
    FocusDemoAction,
    FocusDemoEnvironment
  > { state, action, _ in
    switch action {
    case .binding:
      return .none

    case .signInButtonTapped:
      if state.username.isEmpty {
        state.focusedField = .username
      } else if state.password.isEmpty {
        state.focusedField = .password
      }
      return .none
    }
  }
  .binding()

  struct FocusDemoView: View {
    let store: Store<FocusDemoState, FocusDemoAction>
    @FocusState var focusedField: FocusDemoState.Field?

    var body: some View {
      WithViewStore(self.store) { viewStore in
        VStack(alignment: .leading, spacing: 32) {
          Text(template: readMe, .caption)

          VStack {
            TextField("Username", text: viewStore.binding(\.$username))
              .focused($focusedField, equals: .username)

            SecureField("Password", text: viewStore.binding(\.$password))
              .focused($focusedField, equals: .password)

            Button("Sign In") {
              viewStore.send(.signInButtonTapped)
            }
          }

          Spacer()
        }
        .padding()
        .synchronize(viewStore.binding(\.$focusedField), self.$focusedField)
      }
      .navigationBarTitle("Focus demo")
    }
  }

  extension View {
    func synchronize<Value>(
      _ first: Binding<Value>,
      _ second: FocusState<Value>.Binding
    ) -> some View {
      self
        .onChange(of: first.wrappedValue) { second.wrappedValue = $0 }
        .onChange(of: second.wrappedValue) { first.wrappedValue = $0 }
    }
  }

  struct FocusDemo_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        FocusDemoView(
          store: Store(
            initialState: .init(),
            reducer: focusDemoReducer,
            environment: .init()
          )
        )
      }
    }
  }
#endif
