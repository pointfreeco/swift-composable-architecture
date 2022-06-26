import AuthenticationClient
import Combine
import ComposableArchitecture
import Foundation

extension AuthenticationClient {
  public static let live = AuthenticationClient(
    login: { request in
      var effect: Effect<AuthenticationResponse, AuthenticationError> {
        if request.email.contains("@") && request.password == "password" {
          return Effect(
            value: AuthenticationResponse(
              token: "deadbeef", twoFactorRequired: request.email.contains("2fa")
            )
          )
        } else {
          return Effect(error: .invalidUserPassword)
        }
      }
      return
        effect
        .delay(for: 1, scheduler: queue)
        .eraseToEffect()
    },
    twoFactor: { request in
      var effect: Effect<AuthenticationResponse, AuthenticationError> {
        if request.token != "deadbeef" {
          return Effect(error: .invalidIntermediateToken)
        } else if request.code != "1234" {
          return Effect(error: .invalidTwoFactor)
        } else {
          return Effect(
            value: AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: false)
          )
        }
      }
      return
        effect
        .delay(for: 1, scheduler: queue)
        .eraseToEffect()
    }
  )
}

private let queue = DispatchQueue(label: "AuthenticationClient")
