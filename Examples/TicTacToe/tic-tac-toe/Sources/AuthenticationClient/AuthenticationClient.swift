import Dependencies
import DependenciesMacros
import Foundation

public struct AuthenticationResponse: Equatable, Sendable {
  public var token: String
  public var twoFactorRequired: Bool

  public init(
    token: String,
    twoFactorRequired: Bool
  ) {
    self.token = token
    self.twoFactorRequired = twoFactorRequired
  }
}

public enum AuthenticationError: Equatable, LocalizedError, Sendable {
  case invalidUserPassword
  case invalidTwoFactor
  case invalidIntermediateToken

  public var errorDescription: String? {
    switch self {
    case .invalidUserPassword:
      return "Unknown user or invalid password."
    case .invalidTwoFactor:
      return "Invalid second factor (try 1234)"
    case .invalidIntermediateToken:
      return "404!! What happened to your token there bud?!?!"
    }
  }
}

@DependencyClient
public struct AuthenticationClient: Sendable {
  public var login:
    @Sendable (_ email: String, _ password: String) async throws -> AuthenticationResponse
  public var twoFactor:
    @Sendable (_ code: String, _ token: String) async throws -> AuthenticationResponse
}

extension AuthenticationClient: TestDependencyKey {
  public static let testValue = Self()
}

extension DependencyValues {
  public var authenticationClient: AuthenticationClient {
    get { self[AuthenticationClient.self] }
    set { self[AuthenticationClient.self] = newValue }
  }
}
