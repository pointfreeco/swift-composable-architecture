import AuthenticationClient
import ComposableArchitecture
import Dispatch

public struct Login: ReducerProtocol {
  public struct State: Hashable {
    public var alert: AlertState<Action>?
    public var email = ""
    public var isFormValid = false
    public var isLoginRequestInFlight = false
    public var password = ""

    public init() {}
  }

  public enum Action: Hashable {
    case alertDismissed
    case emailChanged(String)
    case passwordChanged(String)
    case loginButtonTapped
    case loginResponse(TaskResult<AuthenticationResponse>)
  }

  @Dependency(\.authenticationClient) var authenticationClient
  @Dependency(\.mainQueue) var mainQueue

  public init() {}

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .alertDismissed:
        state.alert = nil
        return .none

      case let .emailChanged(email):
        state.email = email
        state.isFormValid = !state.email.isEmpty && !state.password.isEmpty
        return .none

      case let .loginResponse(.success(response)):
        state.isLoginRequestInFlight = false
        return .none

      case let .loginResponse(.failure(error)):
        state.alert = .init(title: TextState(error.localizedDescription))
        state.isLoginRequestInFlight = false
        return .none

      case let .passwordChanged(password):
        state.password = password
        state.isFormValid = !state.email.isEmpty && !state.password.isEmpty
        return .none

      case .loginButtonTapped:
        state.isLoginRequestInFlight = true
        return .task { [email = state.email, password = state.password] in
          .loginResponse(
            await .init {
              try await self.authenticationClient.login(
                .init(email: email, password: password)
              )
            }
          )
        }
      }
    }
  }
}
