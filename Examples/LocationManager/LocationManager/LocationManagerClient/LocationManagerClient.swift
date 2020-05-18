import Combine
import ComposableArchitecture
import CoreLocation

struct LocationManagerClient {
  var authorizationStatus: () -> CLAuthorizationStatus
  var create: (_ id: AnyHashable) -> Effect<Action, Never>
  var destroy: (AnyHashable) -> Effect<Never, Never>
  var locationServicesEnabled: () -> Bool
  var requestLocation: (AnyHashable) -> Effect<Never, Never>
  var requestAlwaysAuthorization: (AnyHashable) -> Effect<Never, Never>
  var requestWhenInUseAuthorization: (AnyHashable) -> Effect<Never, Never>
  var startUpdatingLocation: (AnyHashable) -> Effect<Never, Never>
  var stopUpdatingLocation: (AnyHashable) -> Effect<Never, Never>
  var update:
    (
      _ id: AnyHashable,
      _ activityType: CLActivityType?,
      _ allowsBackgroundLocationUpdates: Bool?,
      _ desiredAccuracy: CLLocationAccuracy?,
      _ distanceFilter: CLLocationDistance?,
      _ pausesLocationUpdatesAutomatically: Bool?,
      _ showsBackgroundLocationIndicator: Bool?
    ) -> Effect<Never, Never>

  func create(
    id: AnyHashable
  ) -> Effect<Action, Never> {
    self.create(id)
  }

  func destroy(id: AnyHashable) -> Effect<Never, Never> {
    self.destroy(id)
  }

  func requestLocation(id: AnyHashable) -> Effect<Never, Never> {
    self.requestLocation(id)
  }

  func requestAlwaysAuthorization(id: AnyHashable) -> Effect<Never, Never> {
    self.requestAlwaysAuthorization(id)
  }

  func requestWhenInUseAuthorization(id: AnyHashable) -> Effect<Never, Never> {
    self.requestWhenInUseAuthorization(id)
  }

  func startUpdatingLocation(id: AnyHashable) -> Effect<Never, Never> {
    self.startUpdatingLocation(id)
  }

  func stopUpdatingLocation(id: AnyHashable) -> Effect<Never, Never> {
    self.stopUpdatingLocation(id)
  }

  func update(
    id: AnyHashable,
    activityType: CLActivityType? = nil,
    allowsBackgroundLocationUpdates: Bool? = nil,
    desiredAccuracy: CLLocationAccuracy? = nil,
    distanceFilter: CLLocationDistance? = nil,
    pausesLocationUpdatesAutomatically: Bool? = nil,
    showsBackgroundLocationIndicator: Bool? = nil
  ) -> Effect<Never, Never> {
    self.update(
      id,
      activityType,
      allowsBackgroundLocationUpdates,
      desiredAccuracy,
      distanceFilter,
      pausesLocationUpdatesAutomatically,
      showsBackgroundLocationIndicator
    )
  }

  enum Action: Equatable {
    case didChangeAuthorization(CLAuthorizationStatus)
    case didCreate(locationServicesEnabled: Bool, authorizationStatus: CLAuthorizationStatus)
    case didFailWithError(Error)
    case didUpdateLocations([Location])
  }

  struct Error: Swift.Error, Equatable {
    init() {}
  }
}
