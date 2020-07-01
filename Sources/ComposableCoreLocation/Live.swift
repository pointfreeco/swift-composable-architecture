import Combine
import ComposableArchitecture
import CoreLocation

extension LocationManager {

  /// The live implementation of the `LocationManager` interface. This implementation is capable of
  /// creating real `CLLocationManager` instances, listening to its delegate methods, and invoking
  /// its methods. You will typically use this when building for the simulator or device:
  ///
  ///     let store = Store(
  ///       initialState: AppState(),
  ///       reducer: appReducer,
  ///       environment: AppEnvironment(
  ///         locationManager: LocationManager.live
  ///       )
  ///     )
  ///
  public static let live: LocationManager = { () -> LocationManager in
    var manager = LocationManager()

    manager.authorizationStatus = CLLocationManager.authorizationStatus

    manager.create = { id in
      Effect.run { subscriber in
        let manager = CLLocationManager()
        var delegate = LocationManagerDelegate(subscriber)
        manager.delegate = delegate

        dependencies[id] = Dependencies(
          delegate: delegate,
          manager: manager,
          subscriber: subscriber
        )

        return AnyCancellable {
          dependencies[id] = nil
        }
      }
    }

    manager.destroy = { id in
      .fireAndForget {
        dependencies[id]?.subscriber.send(completion: .finished)
        dependencies[id] = nil
      }
    }

    manager.locationServicesEnabled = CLLocationManager.locationServicesEnabled

    manager.location = { id in dependencies[id]?.manager.location.map(Location.init(rawValue:)) }

    manager.requestLocation = { id in
      .fireAndForget { dependencies[id]?.manager.requestLocation() }
    }

    #if os(iOS) || os(macOS) || os(watchOS) || targetEnvironment(macCatalyst)
      manager.requestAlwaysAuthorization = { id in
        .fireAndForget { dependencies[id]?.manager.requestAlwaysAuthorization() }
      }
    #endif

    #if os(iOS) || os(tvOS) || os(watchOS) || targetEnvironment(macCatalyst)
      manager.requestWhenInUseAuthorization = { id in
        .fireAndForget { dependencies[id]?.manager.requestWhenInUseAuthorization() }
      }
    #endif

    manager.set = { id, properties in
      .fireAndForget {
        guard let manager = dependencies[id]?.manager else { return }

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
          if let pausesLocationUpdatesAutomatically = properties.pausesLocationUpdatesAutomatically
          {
            manager.pausesLocationUpdatesAutomatically = pausesLocationUpdatesAutomatically
          }
          if let showsBackgroundLocationIndicator = properties.showsBackgroundLocationIndicator {
            manager.showsBackgroundLocationIndicator = showsBackgroundLocationIndicator
          }
        #endif
      }
    }

    #if os(iOS) || targetEnvironment(macCatalyst)
      manager.startMonitoringVisits = { id in
        .fireAndForget { dependencies[id]?.manager.startMonitoringVisits() }
      }
    #endif

    #if os(iOS) || os(macOS) || os(watchOS) || targetEnvironment(macCatalyst)
      manager.startUpdatingLocation = { id in
        .fireAndForget { dependencies[id]?.manager.startUpdatingLocation() }
      }
    #endif

    #if os(iOS) || targetEnvironment(macCatalyst)
      manager.stopMonitoringVisits = { id in
        .fireAndForget { dependencies[id]?.manager.stopMonitoringVisits() }
      }
    #endif

    manager.stopUpdatingLocation = { id in
      .fireAndForget { dependencies[id]?.manager.stopUpdatingLocation() }
    }

    return manager
  }()
}

private struct Dependencies {
  let delegate: LocationManagerDelegate
  let manager: CLLocationManager
  let subscriber: Effect<LocationManager.Action, Never>.Subscriber
}

private var dependencies: [AnyHashable: Dependencies] = [:]

private class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
  let subscriber: Effect<LocationManager.Action, Never>.Subscriber

  init(_ subscriber: Effect<LocationManager.Action, Never>.Subscriber) {
    self.subscriber = subscriber
  }

  func locationManager(
    _ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus
  ) {
    subscriber.send(.didChangeAuthorization(status))
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    subscriber.send(.didFailWithError(LocationManager.Error(error)))
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    subscriber.send(.didUpdateLocations(locations.map(Location.init(rawValue:))))
  }

  #if os(macOS)
    func locationManager(
      _ manager: CLLocationManager, didUpdateTo newLocation: CLLocation,
      from oldLocation: CLLocation
    ) {
      subscriber.send(
        .didUpdateTo(
          newLocation: Location(rawValue: newLocation),
          oldLocation: Location(rawValue: oldLocation)
        )
      )
    }
  #endif

  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    func locationManager(
      _ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?
    ) {
      subscriber.send(.didFinishDeferredUpdatesWithError(error.map(LocationManager.Error.init)))
    }
  #endif

  #if os(iOS) || targetEnvironment(macCatalyst)
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
      subscriber.send(.didPauseLocationUpdates)
    }
  #endif

  #if os(iOS) || targetEnvironment(macCatalyst)
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
      subscriber.send(.didResumeLocationUpdates)
    }
  #endif

  #if os(iOS) || os(watchOS) || targetEnvironment(macCatalyst)
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
      subscriber.send(.didUpdateHeading(newHeading: Heading(rawValue: newHeading)))
    }
  #endif

  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
      subscriber.send(.didEnterRegion(Region(rawValue: region)))
    }
  #endif

  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
      subscriber.send(.didExitRegion(Region(rawValue: region)))
    }
  #endif

  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    func locationManager(
      _ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion
    ) {
      subscriber.send(.didDetermineState(state, region: Region(rawValue: region)))
    }
  #endif

  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    func locationManager(
      _ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error
    ) {
      subscriber.send(
        .monitoringDidFail(
          region: region.map(Region.init(rawValue:)), error: LocationManager.Error(error)))
    }
  #endif

  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
      subscriber.send(.didStartMonitoring(region: Region(rawValue: region)))
    }
  #endif

  #if os(iOS) || targetEnvironment(macCatalyst)
    func locationManager(
      _ manager: CLLocationManager, didRange beacons: [CLBeacon],
      satisfying beaconConstraint: CLBeaconIdentityConstraint
    ) {
      subscriber.send(
        .didRangeBeacons(
          beacons.map(Beacon.init(rawValue:)), satisfyingConstraint: beaconConstraint))
    }
  #endif

  #if os(iOS) || targetEnvironment(macCatalyst)
    func locationManager(
      _ manager: CLLocationManager, didFailRangingFor beaconConstraint: CLBeaconIdentityConstraint,
      error: Error
    ) {
      subscriber.send(
        .didFailRanging(beaconConstraint: beaconConstraint, error: LocationManager.Error(error)))
    }
  #endif

  #if os(iOS) || targetEnvironment(macCatalyst)
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
      subscriber.send(.didVisit(Visit(visit: visit)))
    }
  #endif
}
