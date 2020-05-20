#if DEBUG
  import CoreLocation
  import ComposableArchitecture

  extension LocationManager {
    /// The mock implementation of the `LocationManager` interface. By default this
    /// implementation stubs all of its endpoints as functions that immediately `fatalError`.
    /// So, to construct a mock you will invoke the `.mock` static method, and provide
    /// implementations for all of the endpoints that you expect your test to need access to.
    ///
    /// This allows you to test an even deeper property of your features: that they use only
    /// the location manager endpoints that you specify and nothing else. This can be useful
    /// as a measurement of just how complex a particular test is. Tests that need to stub
    /// many endpoints are in some sense more complicated than tests that only need to stub a
    /// few endpoints. It's not necessarily a bad thing to stub many endpoints, sometimes it's
    /// needed.
    ///
    /// As an example, to create a mock client that simulates a location manager that has already
    /// authorized access to location, and when a location is requested it immediately responds
    /// with a mock location we can do something like this:
    ///
    ///     // Send actions to this subject to simulate the location manager's delegate methods
    ///     // being called.
    ///     let locationManagerSubject = PassthroughSubject<LocationManager.Action, Never>()
    ///
    ///     // The mock location we want the client to say we are located at
    ///     let mockLocation = Location(
    ///       coordinate: CLLocationCoordinate2D(latitude: 40.6501, longitude: -73.94958),
    ///       // A whole bunch of other properties have been omitted.
    ///     )
    ///
    ///     let client = LocationManager.mock(
    ///       // Override any CLLocationManager endpoints your test invokes:
    ///
    ///       authorizationStatus: { .authorizedAlways },
    ///       create: { _ in locationManagerSubject.eraseToEffect() },
    ///       locationServicesEnabled: { true },
    ///       requestLocation: { _ in
    ///         .fireAndForget { locationManagerSubject.send(.didUpdateLocations([mockLocation])) }
    ///       }
    ///     )
    ///
    @available(macOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public static func mock(
      authorizationStatus: @escaping () -> CLAuthorizationStatus = { fatalError() },
      create: @escaping (_ id: AnyHashable) -> Effect<Action, Never> = { _ in fatalError() },
      destroy: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
      dismissHeadingCalibrationDisplay: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
        fatalError()
      },
      heading: @escaping (AnyHashable) -> Heading? = { _ in fatalError() },
      headingAvailable: @escaping () -> Bool = { fatalError() },
      isRangingAvailable: @escaping () -> Bool = { fatalError() },
      location: @escaping (AnyHashable) -> Location = { _ in fatalError() },
      locationServicesEnabled: @escaping () -> Bool = { fatalError() },
      maximumRegionMonitoringDistance: @escaping (AnyHashable) -> CLLocationDistance = { _ in
        fatalError()
      },
      monitoredRegions: @escaping (AnyHashable) -> Set<Region> = { _ in fatalError() },
      requestAlwaysAuthorization: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
        fatalError()
      },
      requestLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
      requestWhenInUseAuthorization: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
        fatalError()
      },
      set: @escaping (_ id: AnyHashable, _ properties: Properties) -> Effect<Never, Never> = {
        _, _ in fatalError()
      },
      significantLocationChangeMonitoringAvailable: @escaping () -> Bool = { fatalError() },
      startMonitoringSignificantLocationChanges: @escaping (AnyHashable) -> Effect<Never, Never> = {
        _ in fatalError()
      },
      startMonitoringForRegion: @escaping (AnyHashable, Region) -> Effect<Never, Never> = { _, _ in
        fatalError()
      },
      startMonitoringVisits: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError()
      },
      startUpdatingLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError()
      },
      stopMonitoringSignificantLocationChanges: @escaping (AnyHashable) -> Effect<Never, Never> = {
        _ in fatalError()
      },
      stopMonitoringForRegion: @escaping (AnyHashable, Region) -> Effect<Never, Never> = { _, _ in
        fatalError()
      },
      stopMonitoringVisits: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
      startUpdatingHeading: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
      stopUpdatingHeading: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
      stopUpdatingLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() }
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
        set: set,
        significantLocationChangeMonitoringAvailable: significantLocationChangeMonitoringAvailable,
        startMonitoringForRegion: startMonitoringForRegion,
        startMonitoringSignificantLocationChanges: startMonitoringSignificantLocationChanges,
        startMonitoringVisits: startMonitoringVisits,
        startUpdatingHeading: startUpdatingHeading,
        startUpdatingLocation: startUpdatingLocation,
        stopMonitoringForRegion: stopMonitoringForRegion,
        stopMonitoringSignificantLocationChanges: stopMonitoringSignificantLocationChanges,
        stopMonitoringVisits: stopMonitoringVisits,
        stopUpdatingHeading: stopUpdatingHeading,
        stopUpdatingLocation: stopUpdatingLocation
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
      dismissHeadingCalibrationDisplay: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
        fatalError()
      },
      heading: @escaping (AnyHashable) -> Heading? = { _ in fatalError() },
      headingAvailable: @escaping () -> Bool = { fatalError() },
      location: @escaping (AnyHashable) -> Location = { _ in fatalError() },
      locationServicesEnabled: @escaping () -> Bool = { fatalError() },
      requestAlwaysAuthorization: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
        fatalError()
      },
      requestLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
      requestWhenInUseAuthorization: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
        fatalError()
      },
      set: @escaping (_ id: AnyHashable, _ properties: Properties) -> Effect<Never, Never> = {
        _, _ in fatalError()
      },
      startUpdatingHeading: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
      startUpdatingLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError()
      },
      stopUpdatingHeading: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
      stopUpdatingLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() }
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
        set: set,
        startUpdatingHeading: startUpdatingHeading,
        startUpdatingLocation: startUpdatingLocation,
        stopUpdatingHeading: stopUpdatingHeading,
        stopUpdatingLocation: stopUpdatingLocation
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
      requestWhenInUseAuthorization: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
        fatalError()
      },
      set: @escaping (_ id: AnyHashable, _ properties: Properties) -> Effect<Never, Never> = {
        _, _ in fatalError()
      },
      stopUpdatingLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() }
    ) -> Self {
      Self(
        authorizationStatus: authorizationStatus,
        create: create,
        destroy: destroy,
        location: location,
        locationServicesEnabled: locationServicesEnabled,
        requestLocation: requestLocation,
        requestWhenInUseAuthorization: requestWhenInUseAuthorization,
        set: set,
        stopUpdatingLocation: stopUpdatingLocation
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
      maximumRegionMonitoringDistance: @escaping (AnyHashable) -> CLLocationDistance = { _ in
        fatalError()
      },
      monitoredRegions: @escaping (AnyHashable) -> Set<Region> = { _ in fatalError() },
      requestAlwaysAuthorization: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
        fatalError()
      },
      requestLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() },
      set: @escaping (_ id: AnyHashable, _ properties: Properties) -> Effect<Never, Never> = {
        _, _ in fatalError()
      },
      significantLocationChangeMonitoringAvailable: @escaping () -> Bool = { fatalError() },
      startMonitoringForRegion: @escaping (AnyHashable, Region) -> Effect<Never, Never> = { _, _ in
        fatalError()
      },
      startMonitoringSignificantLocationChanges: @escaping (AnyHashable) -> Effect<Never, Never> = {
        _ in fatalError()
      },
      startUpdatingLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError()
      },
      stopMonitoringForRegion: @escaping (AnyHashable, Region) -> Effect<Never, Never> = { _, _ in
        fatalError()
      },
      stopMonitoringSignificantLocationChanges: @escaping (AnyHashable) -> Effect<Never, Never> = {
        _ in fatalError()
      },
      stopUpdatingLocation: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() }
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
        set: set,
        significantLocationChangeMonitoringAvailable: significantLocationChangeMonitoringAvailable,
        startMonitoringForRegion: startMonitoringForRegion,
        startMonitoringSignificantLocationChanges: startMonitoringSignificantLocationChanges,
        startUpdatingLocation: startUpdatingLocation,
        stopMonitoringForRegion: stopMonitoringForRegion,
        stopMonitoringSignificantLocationChanges: stopMonitoringSignificantLocationChanges,
        stopUpdatingLocation: stopUpdatingLocation
      )
    }
  }
#endif
