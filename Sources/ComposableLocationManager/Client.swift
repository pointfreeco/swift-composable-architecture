import Combine
import ComposableArchitecture
import CoreLocation

public struct LocationManagerClient {
  public var authorizationStatus: () -> CLAuthorizationStatus
  var create: (_ id: AnyHashable) -> Effect<LocationManagerAction, Never>
  var destroy: (AnyHashable) -> Effect<Never, Never>
  public var locationServicesEnabled: () -> Bool
  var requestLocation: (AnyHashable) -> Effect<Never, Never>
  var requestAlwaysAuthorization: (AnyHashable) -> Effect<Never, Never>
  var requestWhenInUseAuthorization: (AnyHashable) -> Effect<Never, Never>
  var startMonitoringVisits: (AnyHashable) -> Effect<Never, Never>
  var startUpdatingLocation: (AnyHashable) -> Effect<Never, Never>
  var stopMonitoringVisits: (AnyHashable) -> Effect<Never, Never>
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

  public func create(
    id: AnyHashable
  ) -> Effect<LocationManagerAction, Never> {
    self.create(id)
  }

  public func destroy(id: AnyHashable) -> Effect<Never, Never> {
    self.destroy(id)
  }

  public func requestLocation(id: AnyHashable) -> Effect<Never, Never> {
    self.requestLocation(id)
  }

  public func requestAlwaysAuthorization(id: AnyHashable) -> Effect<Never, Never> {
    self.requestAlwaysAuthorization(id)
  }

  public func requestWhenInUseAuthorization(id: AnyHashable) -> Effect<Never, Never> {
    self.requestWhenInUseAuthorization(id)
  }

  public func startMonitoringVisits(id: AnyHashable) -> Effect<Never, Never> {
    self.startMonitoringVisits(id)
  }

  public func startUpdatingLocation(id: AnyHashable) -> Effect<Never, Never> {
    self.startUpdatingLocation(id)
  }

  public func stopMonitoringVisits(id: AnyHashable) -> Effect<Never, Never> {
    self.stopMonitoringVisits(id)
  }

  public func stopUpdatingLocation(id: AnyHashable) -> Effect<Never, Never> {
    self.stopUpdatingLocation(id)
  }

  public func update(
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
}
