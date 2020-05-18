import Combine
import ComposableArchitecture
import CoreLocation

extension LocationManagerClient {
  public static let live = LocationManagerClient(
    authorizationStatus: {
      CLLocationManager.authorizationStatus()
  },
    create: { id in
      Effect.run { callback in
        let manager = CLLocationManager()
        let delegate = LocationManagerDelegate(
          didChangeAuthorization: {
            callback.send(.didChangeAuthorization($0))
        },
          didFailWithError: { _ in
            callback.send(.didFailWithError(LocationManagerError()))
        },
          didUpdateLocations: {
            callback.send(.didUpdateLocations($0.map(Location.init(rawValue:))))
        },
          didVisit: { visit in
            callback.send(.didVisit(Visit(visit: visit)))
        })
        manager.delegate = delegate

        dependencies[id] = Dependencies(
          locationManager: manager,
          locationManagerDelegate: delegate
        )

        return AnyCancellable {
          dependencies[id] = nil
        }
      }
  },
    destroy: { id in
      .fireAndForget {
        dependencies[id] = nil
      }
  },
    locationServicesEnabled: {
      CLLocationManager.locationServicesEnabled()
  },
    requestLocation: { id in
      .fireAndForget {
        dependencies[id]?.locationManager.requestLocation()
      }
  },
    requestAlwaysAuthorization: { id in
      .fireAndForget { dependencies[id]?.locationManager.requestAlwaysAuthorization() }
  },
    requestWhenInUseAuthorization: { id in
      .fireAndForget { dependencies[id]?.locationManager.requestWhenInUseAuthorization() }
  },
    startMonitoringVisits: { id in
      .fireAndForget { dependencies[id]?.locationManager.startMonitoringVisits() }
  },
    startUpdatingLocation: { id in
      .fireAndForget { dependencies[id]?.locationManager.startUpdatingLocation() }
  },
    stopMonitoringVisits: { id in
      .fireAndForget { dependencies[id]?.locationManager.stopMonitoringVisits() }
  },
    stopUpdatingLocation: { id in
      .fireAndForget { dependencies[id]?.locationManager.stopUpdatingLocation() }
  },
    update: {
      id, activityType, allowsBackgroundLocationUpdates, desiredAccuracy, distanceFilter,
      pausesLocationUpdatesAutomatically, showsBackgroundLocationIndicator in
      .fireAndForget {
        guard let manager = dependencies[id]?.locationManager else { return }
        if let pausesLocationUpdatesAutomatically = pausesLocationUpdatesAutomatically {
          manager.pausesLocationUpdatesAutomatically = pausesLocationUpdatesAutomatically
        }
        if let allowsBackgroundLocationUpdates = allowsBackgroundLocationUpdates {
          manager.allowsBackgroundLocationUpdates = allowsBackgroundLocationUpdates
        }
        if let showsBackgroundLocationIndicator = showsBackgroundLocationIndicator {
          manager.showsBackgroundLocationIndicator = showsBackgroundLocationIndicator
        }
        if let distanceFilter = distanceFilter {
          manager.distanceFilter = distanceFilter
        }
        if let desiredAccuracy = desiredAccuracy {
          manager.desiredAccuracy = desiredAccuracy
        }
        if let activityType = activityType {
          manager.activityType = activityType
        }
      }
  })
}

private struct Dependencies {
  let locationManager: CLLocationManager
  let locationManagerDelegate: LocationManagerDelegate
}

private var dependencies: [AnyHashable: Dependencies] = [:]

private class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
  var didChangeAuthorization: (CLAuthorizationStatus) -> Void
  var didFailWithError: (Error) -> Void
  var didUpdateLocations: ([CLLocation]) -> Void
  var didVisit: (CLVisit) -> Void

  init(
    didChangeAuthorization: @escaping (CLAuthorizationStatus) -> Void,
    didFailWithError: @escaping (Error) -> Void,
    didUpdateLocations: @escaping ([CLLocation]) -> Void,
    didVisit: @escaping (CLVisit) -> Void
  ) {
    self.didChangeAuthorization = didChangeAuthorization
    self.didFailWithError = didFailWithError
    self.didUpdateLocations = didUpdateLocations
    self.didVisit = didVisit
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    self.didFailWithError(error)
  }

  func locationManager(
    _ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus
  ) {
    self.didChangeAuthorization(status)
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    self.didUpdateLocations(locations)
  }

  func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
    self.didVisit(visit)
  }
}

