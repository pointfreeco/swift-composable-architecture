import Combine
import ComposableArchitecture
import CoreLocation

struct LocationManagerClient {
  var authorizationStatus: () -> CLAuthorizationStatus
  var create: (_ id: AnyHashable) -> Effect<Action, Never>
  var destroy: (AnyHashable) -> Effect<Never, Never>
  var locationServicesEnabled: () -> Bool
  var requestLocation: (AnyHashable) -> Effect<Never, Never>
  var requestWhenInUseAuthorization: (AnyHashable) -> Effect<Never, Never>

  enum Action: Equatable {
    case didChangeAuthorization(CLAuthorizationStatus)
    case didCreate(locationServicesEnabled: Bool, authorizationStatus: CLAuthorizationStatus)
    case didFailWithError(Error)
    case didUpdateLocations([Location])
  }

  struct Error: Swift.Error, Equatable {}
}
