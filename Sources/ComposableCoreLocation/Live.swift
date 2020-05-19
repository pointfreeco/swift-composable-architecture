import Combine
import ComposableArchitecture
import CoreLocation

extension LocationManagerClient {

  public static let live: LocationManagerClient = { () -> LocationManagerClient in
    var client = LocationManagerClient()

    client.authorizationStatus = CLLocationManager.authorizationStatus

    client.create = { id in
      Effect.run { callback in
        let manager = CLLocationManager()
        var delegate = LocationManagerDelegate()
        delegate.didChangeAuthorization =  {
          callback.send(.didChangeAuthorization($0))
        }
        delegate.didFailWithError = { _ in
          callback.send(.didFailWithError(LocationManagerError()))
        }
        delegate.didUpdateLocations = {
          callback.send(.didUpdateLocations($0.map(Location.init(rawValue:))))
        }
        #if os(iOS) || targetEnvironment(macCatalyst)
        delegate.didVisit = { visit in
          callback.send(.didVisit(Visit(visit: visit)))
        }
        #endif
        manager.delegate = delegate

        dependencies[id] = Dependencies(
          locationManager: manager,
          locationManagerDelegate: delegate
        )

        return AnyCancellable {
          dependencies[id] = nil
        }
      }
    }

    client.destroy = { id in
      .fireAndForget {
        dependencies[id] = nil
      }
    }

    client.locationServicesEnabled = CLLocationManager.locationServicesEnabled

    client.requestLocation = { id in
      .fireAndForget { dependencies[id]?.locationManager.requestLocation() }
    }

    #if os(iOS) || os(macOS) || os(watchOS) || targetEnvironment(macCatalyst)
    client.requestAlwaysAuthorization = { id in
      .fireAndForget { dependencies[id]?.locationManager.requestAlwaysAuthorization() }
    }
    #endif

    #if os(iOS) || os(tvOS) || os(watchOS) || targetEnvironment(macCatalyst)
    client.requestWhenInUseAuthorization = { id in
      .fireAndForget { dependencies[id]?.locationManager.requestWhenInUseAuthorization() }
    }
    #endif

    #if os(iOS) || targetEnvironment(macCatalyst)
    client.startMonitoringVisits = { id in
      .fireAndForget { dependencies[id]?.locationManager.startMonitoringVisits() }
    }
    #endif

    #if os(iOS) || os(macOS) || os(watchOS) || targetEnvironment(macCatalyst)
    client.startUpdatingLocation = { id in
      .fireAndForget { dependencies[id]?.locationManager.startUpdatingLocation() }
    }
    #endif

    #if os(iOS) || targetEnvironment(macCatalyst)
    client.stopMonitoringVisits = { id in
      .fireAndForget { dependencies[id]?.locationManager.stopMonitoringVisits() }
    }
    #endif

    client.stopUpdatingLocation = { id in
      .fireAndForget { dependencies[id]?.locationManager.stopUpdatingLocation() }
    }

    client.update = { id, properties in
      .fireAndForget {
        guard let manager = dependencies[id]?.locationManager else { return }

        #if os(iOS) || os(watchOS) || targetEnvironment(macCatalyst)
        if let activityType = properties.activityType {
          manager.activityType = activityType
        }
        if let allowsBackgroundLocationUpdates = properties.allowsBackgroundLocationUpdates {
          manager.allowsBackgroundLocationUpdates = allowsBackgroundLocationUpdates
        }
        #endif
        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || targetEnvironment(macCatalyst)
        if let desiredAccuracy = properties.desiredAccuracy {
          manager.desiredAccuracy = desiredAccuracy
        }
        if let distanceFilter = properties.distanceFilter {
          manager.distanceFilter = distanceFilter
        }
        #endif
        #if os(iOS) || os(watchOS) || targetEnvironment(macCatalyst)
        if let headingFilter = properties.headingFilter {
          manager.headingFilter = headingFilter
        }
        if let headingOrientation = properties.headingOrientation {
          manager.headingOrientation = headingOrientation
        }
        #endif
        #if os(iOS) || targetEnvironment(macCatalyst)
        if let pausesLocationUpdatesAutomatically = properties.pausesLocationUpdatesAutomatically {
          manager.pausesLocationUpdatesAutomatically = pausesLocationUpdatesAutomatically
        }
        if let showsBackgroundLocationIndicator = properties.showsBackgroundLocationIndicator {
          manager.showsBackgroundLocationIndicator = showsBackgroundLocationIndicator
        }
        #endif
      }
    }

    return client
  }()
}

private struct Dependencies {
  let locationManager: CLLocationManager
  let locationManagerDelegate: LocationManagerDelegate
}

private var dependencies: [AnyHashable: Dependencies] = [:]

private class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
  var didChangeAuthorization: (CLAuthorizationStatus) -> Void = { _ in }
  var didFailWithError: (Error) -> Void = { _ in }
  var didUpdateLocations: ([CLLocation]) -> Void = { _ in }
  #if os(iOS) || targetEnvironment(macCatalyst)
  var didVisit: (CLVisit) -> Void = { _ in }
  #endif

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

  #if os(iOS) || targetEnvironment(macCatalyst)
  func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
    self.didVisit(visit)
  }
  #endif
}

