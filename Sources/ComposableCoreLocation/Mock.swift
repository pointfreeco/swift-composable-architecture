#if DEBUG
import CoreLocation
import ComposableArchitecture

extension LocationManagerClient {
  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public static func mock(
    authorizationStatus: @escaping () -> CLAuthorizationStatus = { fatalError() },
    create: @escaping (_ id: AnyHashable) -> Effect<Action, Never> = { _ in fatalError() },
    destroy: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    dismissHeadingCalibrationDisplay: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    heading: @escaping (AnyHashable) -> Heading? = { _ in fatalError() },
    headingAvailable: @escaping () -> Bool = {  fatalError() },
    isRangingAvailable: @escaping () -> Bool = {  fatalError() },
    location: @escaping (AnyHashable) -> Location = { _ in fatalError() },
    locationServicesEnabled: @escaping () -> Bool = { fatalError() },
    maximumRegionMonitoringDistance: @escaping (AnyHashable) -> CLLocationDistance = { _ in fatalError() },
    monitoredRegions: @escaping (AnyHashable) -> Set<Region> = { _ in fatalError() },
    requestAlwaysAuthorization: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    requestLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    requestWhenInUseAuthorization: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    significantLocationChangeMonitoringAvailable: @escaping () -> Bool = {  fatalError() },
    startMonitoringSignificantLocationChanges: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    startMonitoringForRegion: @escaping (AnyHashable, Region) -> Effect<Never, Never> = { _,_  in fatalError() },
    startMonitoringVisits: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    startUpdatingLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    stopMonitoringSignificantLocationChanges: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    stopMonitoringForRegion: @escaping (AnyHashable, Region) -> Effect<Never, Never> = { _,_  in fatalError() },
    stopMonitoringVisits: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    startUpdatingHeading: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    stopUpdatingHeading: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    stopUpdatingLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    update: @escaping (_ id: AnyHashable, _ properties: Properties) -> Effect<Never, Never> = { _, _ in fatalError() }
  ) -> Self {
    Self(
      authorizationStatus: authorizationStatus,
      create: create,
      destroy: destroy,
      dismissHeadingCalibrationDisplay: dismissHeadingCalibrationDisplay,
      heading: heading,
      headingAvailable: headingAvailable,
      isRangingAvailable: isRangingAvailable,
      location: location,
      locationServicesEnabled: locationServicesEnabled,
      maximumRegionMonitoringDistance: maximumRegionMonitoringDistance,
      monitoredRegions: monitoredRegions,
      requestAlwaysAuthorization: requestAlwaysAuthorization,
      requestLocation: requestLocation,
      requestWhenInUseAuthorization: requestWhenInUseAuthorization,
      significantLocationChangeMonitoringAvailable: significantLocationChangeMonitoringAvailable,
      startMonitoringForRegion: startMonitoringForRegion,
      startMonitoringSignificantLocationChanges: startMonitoringSignificantLocationChanges,
      startMonitoringVisits: startMonitoringVisits,
      startUpdatingLocation: startUpdatingLocation,
      stopMonitoringForRegion: stopMonitoringForRegion,
      stopMonitoringSignificantLocationChanges: stopMonitoringSignificantLocationChanges,
      stopMonitoringVisits: stopMonitoringVisits,
      startUpdatingHeading: startUpdatingHeading,
      stopUpdatingHeading: stopUpdatingHeading,
      stopUpdatingLocation: stopUpdatingLocation,
      update: update
    )
  }

  @available(iOS, unavailable)
  @available(macCatalyst, unavailable)
  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  public static func mock(
    authorizationStatus: @escaping () -> CLAuthorizationStatus = { fatalError() },
    create: @escaping (_ id: AnyHashable) -> Effect<Action, Never> = { _ in fatalError() },
    destroy: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    dismissHeadingCalibrationDisplay: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    heading: @escaping (AnyHashable) -> Heading? = { _ in fatalError() },
    headingAvailable: @escaping () -> Bool = { fatalError() },
    location: @escaping (AnyHashable) -> Location = { _ in fatalError() },
    locationServicesEnabled: @escaping () -> Bool = { fatalError() },
    requestAlwaysAuthorization: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    requestLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    requestWhenInUseAuthorization: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    startUpdatingLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    startUpdatingHeading: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    stopUpdatingHeading: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    stopUpdatingLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    update: @escaping (_ id: AnyHashable, _ properties: Properties) -> Effect<Never, Never> = { _, _ in fatalError() }
  ) -> Self {
    Self(
      authorizationStatus: authorizationStatus,
      create: create,
      destroy: destroy,
      dismissHeadingCalibrationDisplay: dismissHeadingCalibrationDisplay,
      heading: heading,
      headingAvailable: headingAvailable,
      location: location,
      locationServicesEnabled: locationServicesEnabled,
      requestAlwaysAuthorization: requestAlwaysAuthorization,
      requestLocation: requestLocation,
      requestWhenInUseAuthorization: requestWhenInUseAuthorization,
      startUpdatingLocation: startUpdatingLocation,
      startUpdatingHeading: startUpdatingHeading,
      stopUpdatingHeading: stopUpdatingHeading,
      stopUpdatingLocation: stopUpdatingLocation,
      update: update
    )
  }

  @available(iOS, unavailable)
  @available(macCatalyst, unavailable)
  @available(macOS, unavailable)
  @available(watchOS, unavailable)
  public static func mock(
    authorizationStatus: @escaping () -> CLAuthorizationStatus = { fatalError() },
    create: @escaping (_ id: AnyHashable) -> Effect<Action, Never> = { _ in fatalError() },
    destroy: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    location: @escaping (AnyHashable) -> Location = { _ in fatalError() },
    locationServicesEnabled: @escaping () -> Bool = { fatalError() },
    requestLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    requestWhenInUseAuthorization: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    stopUpdatingLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    update: @escaping (_ id: AnyHashable, _ properties: Properties) -> Effect<Never, Never> = { _, _ in fatalError() }
  ) -> Self {
    Self(
      authorizationStatus: authorizationStatus,
      create: create,
      destroy: destroy,
      location: location,
      locationServicesEnabled: locationServicesEnabled,
      requestLocation: requestLocation,
      requestWhenInUseAuthorization: requestWhenInUseAuthorization,
      stopUpdatingLocation: stopUpdatingLocation,
      update: update
    )
  }

  @available(iOS, unavailable)
  @available(macCatalyst, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public static func mock(
    authorizationStatus: @escaping () -> CLAuthorizationStatus = { fatalError() },
    create: @escaping (_ id: AnyHashable) -> Effect<Action, Never> = { _ in fatalError() },
    destroy: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    headingAvailable: @escaping () -> Bool = { fatalError() },
    location: @escaping (AnyHashable) -> Location = { _ in fatalError() },
    locationServicesEnabled: @escaping () -> Bool = { fatalError() },
    maximumRegionMonitoringDistance: @escaping (AnyHashable) -> CLLocationDistance = { _ in fatalError() },
    monitoredRegions: @escaping (AnyHashable) -> Set<Region> = { _ in fatalError() },
    requestAlwaysAuthorization: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    requestLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    significantLocationChangeMonitoringAvailable: @escaping () -> Bool = { fatalError() },
    startMonitoringForRegion: @escaping (AnyHashable, Region) -> Effect<Never, Never> = { _, _ in fatalError() },
    startMonitoringSignificantLocationChanges: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    startUpdatingLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    stopMonitoringForRegion: @escaping (AnyHashable, Region) -> Effect<Never, Never> = { _, _ in fatalError() },
    stopMonitoringSignificantLocationChanges: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    stopUpdatingLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
    update: @escaping (_ id: AnyHashable, _ properties: Properties) -> Effect<Never, Never> = { _, _ in fatalError() }
  ) -> Self {
    Self(
      authorizationStatus: authorizationStatus,
      create: create,
      destroy: destroy,
      headingAvailable: headingAvailable,
      location: location,
      locationServicesEnabled: locationServicesEnabled,
      maximumRegionMonitoringDistance: maximumRegionMonitoringDistance,
      monitoredRegions: monitoredRegions,
      requestAlwaysAuthorization: requestAlwaysAuthorization,
      requestLocation: requestLocation,
      significantLocationChangeMonitoringAvailable: significantLocationChangeMonitoringAvailable,
      startMonitoringForRegion: startMonitoringForRegion,
      startMonitoringSignificantLocationChanges: startMonitoringSignificantLocationChanges,
      startUpdatingLocation: startUpdatingLocation,
      stopMonitoringForRegion: stopMonitoringForRegion,
      stopMonitoringSignificantLocationChanges: stopMonitoringSignificantLocationChanges,
      stopUpdatingLocation: stopUpdatingLocation,
      update: update
    )
  }
}
#endif
