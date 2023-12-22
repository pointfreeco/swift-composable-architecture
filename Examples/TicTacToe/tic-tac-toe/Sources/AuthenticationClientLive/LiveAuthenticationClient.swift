import AuthenticationClient
import Dependencies
import Foundation

extension AuthenticationClient: DependencyKey {
  public static let liveValue = Self(
    login: { email, password in
      guard email.contains("@") && password == "password"
      else { throw AuthenticationError.invalidUserPassword }

      try await Task.sleep(for: .seconds(1))
      return AuthenticationResponse(
        token: "deadbeef", twoFactorRequired: email.contains("2fa")
      )
    },
    twoFactor: { code, token in
      guard token == "deadbeef"
      else { throw AuthenticationError.invalidIntermediateToken }

      guard code == "1234"
      else { throw AuthenticationError.invalidTwoFactor }

      try await Task.sleep(for: .seconds(1))
      return AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: false)
    }
  )
}
