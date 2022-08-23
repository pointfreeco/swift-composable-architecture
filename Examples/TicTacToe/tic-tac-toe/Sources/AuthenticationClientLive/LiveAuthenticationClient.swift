import AuthenticationClient
import Dependencies
import Foundation

extension DependencyValues.AuthenticationClientKey: DependencyKey {
  public static let liveValue = AuthenticationClient.live
}

extension AuthenticationClient {
  public static let live = AuthenticationClient(
    login: { request in
      guard request.email.contains("@") && request.password == "password"
      else { throw AuthenticationError.invalidUserPassword }

      try await Task.sleep(nanoseconds: NSEC_PER_SEC)
      return AuthenticationResponse(
        token: "deadbeef", twoFactorRequired: request.email.contains("2fa")
      )
    },
    twoFactor: { request in
      guard request.token == "deadbeef"
      else { throw AuthenticationError.invalidIntermediateToken }

      guard request.code == "1234"
      else { throw AuthenticationError.invalidTwoFactor }

      try await Task.sleep(nanoseconds: NSEC_PER_SEC)
      return AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: false)
    }
  )
}
