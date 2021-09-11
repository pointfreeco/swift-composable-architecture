import ComposableArchitecture
import SwiftUI

private let readMe = """
  This demonstrates how to make use of SwiftUI's `@FocusState` in the Composable Architecture. \
  If you tap the "Sign in" button while a field is empty, the focus will be changed to that field.
  """

struct FocusDemoState: Equatable {
  @BindableState var colorScheme: ColorScheme = .light
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

#if compiler(>=5.5)
  struct FocusDemoView: View {
    let store: Store<FocusDemoState, FocusDemoAction>
    @FocusState var focusedField: FocusDemoState.Field?

    @Environment(\.colorScheme) var colorScheme

    @ObservedObject var viewStore: ViewStore<FocusDemoState, FocusDemoAction>
    init(store: Store<FocusDemoState, FocusDemoAction>) {
      self.store = store
      self.viewStore = ViewStore(self.store)
    }

    @State var otherColorScheme: ColorScheme = .light

    var body: some View {

        NavigationView {
//      WithViewStore(self.store) { viewStore in
        VStack(alignment: .leading, spacing: 32) {
          Text(template: readMe, .caption)

          VStack {
            TextField("Username", text: viewStore.$username)
              .focused($focusedField, equals: .username)

            SecureField("Password", text: viewStore.$password)
              .focused($focusedField, equals: .password)

            Button("Sign In") {
              viewStore.$colorScheme.wrappedValue = viewStore.$colorScheme.wrappedValue == .dark ? .light : .dark
              viewStore.send(.signInButtonTapped)
            }

            Button("Change") {
              self.otherColorScheme = self.otherColorScheme == .light ? .dark : .light
            }
          }

          Spacer()
        }
        .padding()
        .synchronize(viewStore.$focusedField, self.$focusedField)
      }
      .navigationBarTitle("Focus demo")
      .environment(\.colorScheme, self.otherColorScheme)
      .synchronize(viewStore.$colorScheme, self._colorScheme, \.colorScheme)
//      .environment(<#T##keyPath: WritableKeyPath<EnvironmentValues, V>##WritableKeyPath<EnvironmentValues, V>#>, <#T##value: V##V#>)
    }
  }

extension View {
  func synchronize<Value: Equatable>(
    _ first: Binding<Value>,
    _ environmentValue: Environment<Value>,
    _ second: WritableKeyPath<EnvironmentValues, Value>
  ) -> some View {
    self
      .onChange(of: environmentValue.wrappedValue) { first.wrappedValue = $0 }
      .environment(second, first.wrappedValue)
      .onAppear { first.wrappedValue = environmentValue.wrappedValue }
  }
}

  extension View {
    func synchronize<Value: Equatable>(
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
      FocusDemoView(
        store: Store(
          initialState: .init(),
          reducer: focusDemoReducer,
          environment: .init()
        )
      )
    }
  }
#endif
