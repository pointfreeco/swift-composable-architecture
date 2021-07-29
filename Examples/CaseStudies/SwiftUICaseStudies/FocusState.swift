import SwiftUI

class LoginViewModel: ObservableObject {
  @Published var username = ""
  @Published var password = ""
  @Published var focusedField: LoginForm.Field?

  func signInButtonTapped() async {
    if username.isEmpty {
      focusedField = .username
    } else if password.isEmpty {
      focusedField = .password
    } else {
      focusedField = nil
      do {
        // try await handleLogin(username, password)
      } catch {
        self.focusedField = .username
      }
    }
  }
}

struct LoginForm: View {
  enum Field: Hashable {
    case username
    case password
  }

//  @State private var username = ""
//  @State private var password = ""
  @FocusState private var focusedField: Field?
  @ObservedObject var viewModel: LoginViewModel

  var body: some View {
    VStack {
      TextField("Username", text: $viewModel.username)
        .focused($focusedField, equals: .username)

      SecureField("Password", text: $viewModel.password)
        .focused($focusedField, equals: .password)

      Button("Sign In") {
//        Task {
//          for await focusedField = viewModel.signInButtonTapped() {
//            self.focusedField = focusedField
//          }
//        }


        Task {
          await viewModel.signInButtonTapped()
        }

//        if let focusedField = viewModel.signInButtonTapped() {
//          self.focusedField = focusedField
//        }
      }
      
      Text("\(String(describing: self.viewModel.focusedField))")
    }
//    .onChange(of: self.viewModel.focusedField) { newValue in
//      self.focusedField = newValue
//    }
//    .onChange(of: self.focusedField) { newValue in
//      self.viewModel.focusedField = newValue
//    }
    .synchronize(self.$viewModel.focusedField, self.$focusedField)
  }
}

extension View {
  func synchronize<Value: Equatable>(
    _ first: Binding<Value>,
    _ second: Binding<Value>
  ) -> some View {
    self
      .onChange(of: first.wrappedValue) { second.wrappedValue = $0 }
      .onChange(of: second.wrappedValue) { first.wrappedValue = $0 }
  }

  func synchronize<Value: Equatable>(
    _ first: Binding<Value>,
    _ second: FocusState<Value>.Binding
  ) -> some View {
    self
      .onChange(of: first.wrappedValue) { second.wrappedValue = $0 }
      .onChange(of: second.wrappedValue) { first.wrappedValue = $0 }
  }
}
