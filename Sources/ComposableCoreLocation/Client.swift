import Combine
import ComposableArchitecture
import CoreLocation

/// A wrapper around CoreLocation's `CLLocationManager` that exposes its functionality through
/// effects and actions, making it easy to use with the Composable Architecture and easy to test.
///
/// Typically one uses the `.live` implementation of this client when running your app in the
/// simulator or on device:
///
///     let store = Store(
///       initialState: AppState(),
///       reducer: appReducer,
///       environment: AppEnvironment(
///         locationManager: LocationManagerClient.live
///       )
///     )
///
///  In your application's actions you must make room for all of the delegate actions that the
///  location manager can send:
///
///      enum AppAction {
///        case locationManager(LocationManagerClient.Action)
///        // Other actions...
///      }
///
///  In the reducer you create a location manager by returning the `.create` effect from an
///  action, say for example, an `.onAppear` action:
///
///     let appReducer = AppReducer<AppState, AppAction, AppEnvironment> {
///       state, action, environment in
///
///       // A unique identifier for our location manager, just in case we want to use more than
///       // one in your application.
///       struct LocationManagerId: Hashable {}
///
///       switch action {
///       case .onAppear:
///         // Create the location manager
///         return environment.locationManager.create(id: LocationManagerId())
///           .map(AppAction.locationManager)
///
///       // Tap into which ever `CLLocationManagerDelegate` methods you are interested in
///       case .locationManager(.didChangeAuthorization(.authorizedAlways)),
///            .locationManager(.didChangeAuthorization(.authorizedWhenInUse)):
///         // Do something when user authorization location access
///
///       case .locationManager(.didChangeAuthorization(.denied)),
///            .locationManager(.didChangeAuthorization(.restricted)):
///         // Do something when user denies location access
///
///       case let .locationManager(.didUpdateLocations(locations)):
///         // Do something with user's current location.
///       }
///     }
///
///  And finally, one can use the `.mock` implementation in tests:
///
///     let store = TestStore(
///       initialState: AppState(),
///       reducer: appReducer,
///       environment: AppEnvironment(
///         locationManager: LocationManagerClient.mock(
///           // override any manager endpoints used by your test, e.g.
///           authorizationStatus: { .authorizedAlways }
///         )
///       )
///     )
///
/// It is also helpful to use `LocationManagerClient.mock` in SwiftUI previews. Most of the
/// features of `CLLocationManager` do not work in SwiftUI previews, and so by using
/// the `.mock` version you can access a little more functionality without needing to run
/// your application in a simulator or device.
///
public struct LocationManagerClient {

  public enum Action: Equatable {
    case didChangeAuthorization(CLAuthorizationStatus)

    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    case didDetermineState(CLRegionState, region: Region)

    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    case didEnterRegion(Region)

    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    case didExitRegion(Region)

    @available(macOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    case didFailRanging(beaconConstraint: CLBeaconIdentityConstraint, error: Error)

    case didFailWithError(Error)

    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    case didFinishDeferredUpdatesWithError(Error?)

    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    case didPauseLocationUpdates

    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    case didResumeLocationUpdates

    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    case didStartMonitoring(region: Region)

    @available(macOS, unavailable)
    @available(tvOS, unavailable)
    case didUpdateHeading(newHeading: Heading)

    case didUpdateLocations([Location])

    @available(macCatalyst, deprecated: 13)
    @available(tvOS, unavailable)
    case didUpdateTo(newLocation: Location, oldLocation: Location)

    @available(macOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    case didVisit(Visit)

    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    case monitoringDidFail(region: Region?, error: Error)
  }

  public struct Error: Swift.Error, Equatable {
    public let error: NSError

    public init(_ error: Swift.Error) {
      self.error = error as NSError
    }
  }

  public var authorizationStatus: () -> CLAuthorizationStatus = {
    _unimplemented("authorizationStatus")
  }

  var create: (AnyHashable) -> Effect<Action, Never> = { _ in _unimplemented("create") }

  var destroy: (AnyHashable) -> Effect<Never, Never> = { _ in _unimplemented("destroy") }

  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  var dismissHeadingCalibrationDisplay: (AnyHashable) -> Effect<Never, Never> = { _ in
    _unimplemented("dismissHeadingCalibrationDisplay")
  }

  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  var heading: (AnyHashable) -> Heading? = { _ in _unimplemented("heading") }

  @available(tvOS, unavailable)
  public var headingAvailable: () -> Bool = { _unimplemented("headingAvailable") }

  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public var isRangingAvailable: () -> Bool = { _unimplemented("isRangingAvailable") }

  var location: (AnyHashable) -> Location = { _ in _unimplemented("location") }

  public var locationServicesEnabled: () -> Bool = { _unimplemented("locationServicesEnabled") }

  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  var maximumRegionMonitoringDistance: (AnyHashable) -> CLLocationDistance = { _ in
    _unimplemented("maximumRegionMonitoringDistance")
  }

  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  var monitoredRegions: (AnyHashable) -> Set<Region> = { _ in _unimplemented("monitoredRegions") }

  @available(tvOS, unavailable)
  var requestAlwaysAuthorization: (AnyHashable) -> Effect<Never, Never> = { _ in
    _unimplemented("requestAlwaysAuthorization")
  }

  var requestLocation: (AnyHashable) -> Effect<Never, Never> = { _ in
    _unimplemented("requestLocation")
  }

  @available(macOS, unavailable)
  var requestWhenInUseAuthorization: (AnyHashable) -> Effect<Never, Never> = { _ in
    _unimplemented("requestWhenInUseAuthorization")
  }

  var set: (AnyHashable, Properties) -> Effect<Never, Never> = { _, _ in _unimplemented("set") }

  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public var significantLocationChangeMonitoringAvailable: () -> Bool = {
    _unimplemented("significantLocationChangeMonitoringAvailable")
  }

  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  var startMonitoringForRegion: (AnyHashable, Region) -> Effect<Never, Never> = { _, _ in
    _unimplemented("startMonitoringForRegion")
  }

  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  var startMonitoringSignificantLocationChanges: (AnyHashable) -> Effect<Never, Never> = { _ in
    _unimplemented("startMonitoringSignificantLocationChanges")
  }

  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  var startMonitoringVisits: (AnyHashable) -> Effect<Never, Never> = { _ in
    _unimplemented("startMonitoringVisits")
  }

  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  var startUpdatingHeading: (AnyHashable) -> Effect<Never, Never> = { _ in
    _unimplemented("startUpdatingHeading")
  }

  @available(tvOS, unavailable)
  var startUpdatingLocation: (AnyHashable) -> Effect<Never, Never> = { _ in
    _unimplemented("startUpdatingLocation")
  }

  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  var stopMonitoringForRegion: (AnyHashable, Region) -> Effect<Never, Never> = { _, _ in
    _unimplemented("stopMonitoringForRegion")
  }

  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  var stopMonitoringSignificantLocationChanges: (AnyHashable) -> Effect<Never, Never> = { _ in
    _unimplemented("stopMonitoringSignificantLocationChanges")
  }

  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  var stopMonitoringVisits: (AnyHashable) -> Effect<Never, Never> = { _ in
    _unimplemented("stopMonitoringVisits")
  }

  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  var stopUpdatingHeading: (AnyHashable) -> Effect<Never, Never> = { _ in
    _unimplemented("stopUpdatingHeading")
  }

  var stopUpdatingLocation: (AnyHashable) -> Effect<Never, Never> = { _ in
    _unimplemented("stopUpdatingLocation")
  }

  public func create(id: AnyHashable) -> Effect<Action, Never> {
    self.create(id)
  }

  public func destroy(id: AnyHashable) -> Effect<Never, Never> {
    self.destroy(id)
  }

  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  public func dismissHeadingCalibrationDisplay(id: AnyHashable) -> Effect<Never, Never> {
    self.dismissHeadingCalibrationDisplay(id)
  }

  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  public func heading(id: AnyHashable) -> Heading? { self.heading(id) }

  public func location(id: AnyHashable) -> Location { self.location(id) }

  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public func maximumRegionMonitoringDistance(id: AnyHashable) -> CLLocationDistance {
    self.maximumRegionMonitoringDistance(id)
  }

  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public func monitoredRegions(id: AnyHashable) -> Set<Region> { self.monitoredRegions(id) }

  @available(tvOS, unavailable)
  public func requestAlwaysAuthorization(id: AnyHashable) -> Effect<Never, Never> {
    self.requestAlwaysAuthorization(id)
  }

  public func requestLocation(id: AnyHashable) -> Effect<Never, Never> { self.requestLocation(id) }

  @available(macOS, unavailable)
  public func requestWhenInUseAuthorization(id: AnyHashable) -> Effect<Never, Never> {
    self.requestWhenInUseAuthorization(id)
  }

  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public func set(
    id: AnyHashable,
    activityType: CLActivityType? = nil,
    allowsBackgroundLocationUpdates: Bool? = nil,
    desiredAccuracy: CLLocationAccuracy? = nil,
    distanceFilter: CLLocationDistance? = nil,
    headingFilter: CLLocationDegrees? = nil,
    headingOrientation: CLDeviceOrientation? = nil,
    pausesLocationUpdatesAutomatically: Bool? = nil,
    showsBackgroundLocationIndicator: Bool? = nil
  ) -> Effect<Never, Never> {
    self.set(
      id,
      Properties(
        activityType: activityType,
        allowsBackgroundLocationUpdates: allowsBackgroundLocationUpdates,
        desiredAccuracy: desiredAccuracy,
        distanceFilter: distanceFilter,
        headingFilter: headingFilter,
        headingOrientation: headingOrientation,
        pausesLocationUpdatesAutomatically: pausesLocationUpdatesAutomatically,
        showsBackgroundLocationIndicator: showsBackgroundLocationIndicator
      )
    )
  }

  @available(iOS, unavailable)
  @available(macCatalyst, unavailable)
  @available(watchOS, unavailable)
  public func set(
    id: AnyHashable,
    desiredAccuracy: CLLocationAccuracy? = nil,
    distanceFilter: CLLocationDistance? = nil
  ) -> Effect<Never, Never> {
    self.set(
      id,
      Properties(
        desiredAccuracy: desiredAccuracy,
        distanceFilter: distanceFilter
      )
    )
  }

  @available(iOS, unavailable)
  @available(macCatalyst, unavailable)
  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  public func set(
    id: AnyHashable,
    activityType: CLActivityType? = nil,
    allowsBackgroundLocationUpdates: Bool? = nil,
    desiredAccuracy: CLLocationAccuracy? = nil,
    distanceFilter: CLLocationDistance? = nil,
    headingFilter: CLLocationDegrees? = nil,
    headingOrientation: CLDeviceOrientation? = nil
  ) -> Effect<Never, Never> {
    self.set(
      id,
      Properties(
        activityType: activityType,
        allowsBackgroundLocationUpdates: allowsBackgroundLocationUpdates,
        desiredAccuracy: desiredAccuracy,
        distanceFilter: distanceFilter,
        headingFilter: headingFilter,
        headingOrientation: headingOrientation
      )
    )
  }
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public func startMonitoringForRegion(id: AnyHashable, region: Region) -> Effect<Never, Never> {
    self.startMonitoringForRegion(id, region)
  }

  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public func startMonitoringSignificantLocationChanges(id: AnyHashable) -> Effect<Never, Never> {
    self.startMonitoringSignificantLocationChanges(id)
  }

  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public func startMonitoringVisits(id: AnyHashable) -> Effect<Never, Never> {
    self.startMonitoringVisits(id)
  }

  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  public func startUpdatingHeading(id: AnyHashable) -> Effect<Never, Never> {
    self.startUpdatingHeading(id)
  }

  @available(tvOS, unavailable)
  public func startUpdatingLocation(id: AnyHashable) -> Effect<Never, Never> {
    self.startUpdatingLocation(id)
  }

  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public func stopMonitoringForRegion(id: AnyHashable, region: Region) -> Effect<Never, Never> {
    self.stopMonitoringForRegion(id, region)
  }

  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public func stopMonitoringSignificantLocationChanges(id: AnyHashable) -> Effect<Never, Never> {
    self.stopMonitoringSignificantLocationChanges(id)
  }

  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public func stopMonitoringVisits(id: AnyHashable) -> Effect<Never, Never> {
    self.stopMonitoringVisits(id)
  }

  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  public func stopUpdatingHeading(id: AnyHashable) -> Effect<Never, Never> {
    self.stopUpdatingHeading(id)
  }

  public func stopUpdatingLocation(id: AnyHashable) -> Effect<Never, Never> {
    self.stopUpdatingLocation(id)
  }
}

extension LocationManagerClient {
  public struct Properties: Equatable {
    @available(macOS, unavailable)
    @available(tvOS, unavailable)
    var activityType: CLActivityType? = nil

    @available(macOS, unavailable)
    @available(tvOS, unavailable)
    var allowsBackgroundLocationUpdates: Bool? = nil

    var desiredAccuracy: CLLocationAccuracy? = nil

    var distanceFilter: CLLocationDistance? = nil

    @available(macOS, unavailable)
    @available(tvOS, unavailable)
    var headingFilter: CLLocationDegrees? = nil

    @available(macOS, unavailable)
    @available(tvOS, unavailable)
    var headingOrientation: CLDeviceOrientation? = nil

    @available(macOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    var pausesLocationUpdatesAutomatically: Bool? = nil

    @available(macOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    var showsBackgroundLocationIndicator: Bool? = nil

    public static func == (lhs: Self, rhs: Self) -> Bool {
      var isEqual = true
      #if os(iOS) || targetEnvironment(macCatalyst) || os(watchOS)
        isEqual =
          isEqual
          && lhs.activityType == rhs.activityType
          && lhs.allowsBackgroundLocationUpdates == rhs.allowsBackgroundLocationUpdates
      #endif
      isEqual =
        isEqual
        && lhs.desiredAccuracy == rhs.desiredAccuracy
        && lhs.distanceFilter == rhs.distanceFilter
      #if os(iOS) || targetEnvironment(macCatalyst) || os(watchOS)
        isEqual =
          isEqual
          && lhs.headingFilter == rhs.headingFilter
          && lhs.headingOrientation == rhs.headingOrientation
      #endif
      #if os(iOS) || targetEnvironment(macCatalyst)
        isEqual =
          isEqual
          && lhs.pausesLocationUpdatesAutomatically == rhs.pausesLocationUpdatesAutomatically
          && lhs.showsBackgroundLocationIndicator == rhs.showsBackgroundLocationIndicator
      #endif
      return isEqual
    }

    @available(macOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    init(
      activityType: CLActivityType? = nil,
      allowsBackgroundLocationUpdates: Bool? = nil,
      desiredAccuracy: CLLocationAccuracy? = nil,
      distanceFilter: CLLocationDistance? = nil,
      headingFilter: CLLocationDegrees? = nil,
      headingOrientation: CLDeviceOrientation? = nil,
      pausesLocationUpdatesAutomatically: Bool? = nil,
      showsBackgroundLocationIndicator: Bool? = nil
    ) {
      self.activityType = activityType
      self.allowsBackgroundLocationUpdates = allowsBackgroundLocationUpdates
      self.desiredAccuracy = desiredAccuracy
      self.distanceFilter = distanceFilter
      self.headingFilter = headingFilter
      self.headingOrientation = headingOrientation
      self.pausesLocationUpdatesAutomatically = pausesLocationUpdatesAutomatically
      self.showsBackgroundLocationIndicator = showsBackgroundLocationIndicator
    }

    @available(iOS, unavailable)
    @available(macCatalyst, unavailable)
    @available(watchOS, unavailable)
    init(
      desiredAccuracy: CLLocationAccuracy? = nil,
      distanceFilter: CLLocationDistance? = nil
    ) {
      self.desiredAccuracy = desiredAccuracy
      self.distanceFilter = distanceFilter
    }

    @available(iOS, unavailable)
    @available(macCatalyst, unavailable)
    @available(macOS, unavailable)
    @available(tvOS, unavailable)
    init(
      activityType: CLActivityType? = nil,
      allowsBackgroundLocationUpdates: Bool? = nil,
      desiredAccuracy: CLLocationAccuracy? = nil,
      distanceFilter: CLLocationDistance? = nil,
      headingFilter: CLLocationDegrees? = nil,
      headingOrientation: CLDeviceOrientation? = nil
    ) {
      self.activityType = activityType
      self.allowsBackgroundLocationUpdates = allowsBackgroundLocationUpdates
      self.desiredAccuracy = desiredAccuracy
      self.distanceFilter = distanceFilter
      self.headingFilter = headingFilter
      self.headingOrientation = headingOrientation
    }
  }
}

public func _unimplemented(
  _ function: StaticString, file: StaticString = #file, line: UInt = #line
) -> Never {
  fatalError(
    """
    \(function) was called but is not implemented. Provide an implementation to \
    "LocationManagerClient.mock".
    """,
    file: file,
    line: line
  )
}
