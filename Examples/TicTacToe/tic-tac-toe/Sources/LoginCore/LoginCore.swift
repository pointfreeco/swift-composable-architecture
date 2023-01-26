import AuthenticationClient
import ComposableArchitecture
import Dispatch
import TwoFactorCore

public struct Login: ReducerProtocol, Sendable {
  public struct State: Equatable {
    @PresentationStateOf<Destinations> public var destination
    public var email = ""
    public var isFormValid = false
    public var isLoginRequestInFlight = false
    public var password = ""

    public init() {}
  }

  public enum Action: Equatable {
    case destination(PresentationActionOf<Destinations>)
    case emailChanged(String)
    case loginButtonTapped
    case loginResponse(TaskResult<AuthenticationResponse>)
    case passwordChanged(String)
  }

  public struct Destinations: ReducerProtocol {
    public enum State: Equatable {
      case alert(AlertState<Never>)
      case twoFactor(TwoFactor.State)
    }

    public enum Action: Equatable {
      case alert(Never)
      case twoFactor(TwoFactor.Action)
    }

    public var body: some ReducerProtocol<State, Action> {
      Scope(
        state: /State.twoFactor,
        action: /Action.twoFactor
      ) {
        TwoFactor()
      }
    }
  }

  @Dependency(\.authenticationClient) var authenticationClient

  public init() {}

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .destination:
        return .none

      case let .emailChanged(email):
        state.email = email
        state.isFormValid = !state.email.isEmpty && !state.password.isEmpty
        return .none

      case .loginButtonTapped:
        state.isLoginRequestInFlight = true
        return .task { [email = state.email, password = state.password] in
          .loginResponse(
            await TaskResult {
              try await self.authenticationClient.login(
                .init(email: email, password: password)
              )
            }
          )
        }

      case let .loginResponse(.success(response)):
        state.isLoginRequestInFlight = false
        if response.twoFactorRequired {
          state.destination = .twoFactor(TwoFactor.State(token: response.token))
        }
        return .none

      case let .loginResponse(.failure(error)):
        state.destination = .alert(AlertState { TextState(error.localizedDescription) })
        state.isLoginRequestInFlight = false
        return .none

      case let .passwordChanged(password):
        state.password = password
        state.isFormValid = !state.email.isEmpty && !state.password.isEmpty
        return .none
      }
    }
    .presentationDestination(\.$destination, action: /Action.destination) {
      Destinations()
    }
  }
}
