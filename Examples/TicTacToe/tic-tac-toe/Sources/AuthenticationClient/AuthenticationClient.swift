import Dependencies
import Foundation
import XCTestDynamicOverlay

public struct LoginRequest: Sendable {
  public var email: String
  public var password: String

  public init(
    email: String,
    password: String
  ) {
    self.email = email
    self.password = password
  }
}

public struct TwoFactorRequest {
  public var code: String
  public var token: String

  public init(
    code: String,
    token: String
  ) {
    self.code = code
    self.token = token
  }
}

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

public struct AuthenticationClient: Sendable {
  public var login: @Sendable (LoginRequest) async throws -> AuthenticationResponse
  public var twoFactor: @Sendable (TwoFactorRequest) async throws -> AuthenticationResponse

  public init(
    login: @escaping @Sendable (LoginRequest) async throws -> AuthenticationResponse,
    twoFactor: @escaping @Sendable (TwoFactorRequest) async throws -> AuthenticationResponse
  ) {
    self.login = login
    self.twoFactor = twoFactor
  }
}

extension AuthenticationClient: TestDependencyKey {
  public static let testValue = Self(
    login: unimplemented("\(Self.self).login"),
    twoFactor: unimplemented("\(Self.self).twoFactor")
  )
}

extension DependencyValues {
  public var authenticationClient: AuthenticationClient {
    get { self[AuthenticationClient.self] }
    set { self[AuthenticationClient.self] = newValue }
  }
}
