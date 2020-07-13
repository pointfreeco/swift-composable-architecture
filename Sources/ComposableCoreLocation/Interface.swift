import Combine
import ComposableArchitecture
import CoreLocation

/// A wrapper around Core Location's `CLLocationManager` that exposes its functionality through
/// effects and actions, making it easy to use with the Composable Architecture and easy to test.
///
/// To use it, one begins by adding an action to your domain that represents all of the actions the
/// manager can emit via the `CLLocationManagerDelegate` methods:
///
///     import ComposableCoreLocation
///
///     enum AppAction {
///       case locationManager(LocationManager.Action)
///
///       // Your domain's other actions:
///       ...
///     }
///
/// The `LocationManager.Action` enum holds a case for each delegate method of
/// `CLLocationManagerDelegate`, such as `didUpdateLocations`, `didEnterRegion`, `didUpdateHeading`,
/// and more.
///
/// Next we add a `LocationManager`, which is a wrapper around `CLLocationManager` that the library
/// provides, to the application's environment of dependencies:
///
///     struct AppEnvironment {
///       var locationManager: LocationManager
///
///       // Your domain's other dependencies:
///       ...
///     }
///
/// Then, we create a location manager and request authorization from our application's reducer by
/// returning an effect from an action to kick things off. One good choice for such an action is the
/// `onAppear` of your view. You must also provide a unique identifier to associate with the
/// location manager you create since it is possible to have multiple managers running at once.
///
///     let appReducer = Reducer<AppState, AppAction, AppEnvironment> {
///       state, action, environment in
///
///       // A unique identifier for our location manager, just in case we want to use
///       // more than one in our application.
///       struct LocationManagerId: Hashable {}
///
///       switch action {
///       case .onAppear:
///         return .merge(
///           environment.locationManager
///             .create(id: LocationManagerId())
///             .map(AppAction.locationManager),
///
///           environment.locationManager
///             .requestWhenInUseAuthorization(id: LocationManagerId())
///             .fireAndForget()
///           )
///
///       ...
///       }
///     }
///
/// With that initial setup we will now get all of `CLLocationManagerDelegate`'s delegate methods
/// delivered to our reducer via actions. To handle a particular delegate action we can destructure
/// it inside the `.locationManager` case we added to our `AppAction`. For example, once we get
/// location authorization from the user we could request their current location:
///
///     case .locationManager(.didChangeAuthorization(.authorizedAlways)),
///          .locationManager(.didChangeAuthorization(.authorizedWhenInUse)):
///
///       return environment.locationManager
///         .requestLocation(id: LocationManagerId())
///         .fireAndForget()
///
/// If the user denies location access we can show an alert telling them that we need access to be
/// able to do anything in the app:
///
///     case .locationManager(.didChangeAuthorization(.denied)),
///          .locationManager(.didChangeAuthorization(.restricted)):
///
///       state.alert = """
///         Please give location access so that we can show you some cool stuff.
///         """
///       return .none
///
/// Otherwise, we'll be notified of the user's location by handling the `.didUpdateLocations`
/// action:
///
///     case let .locationManager(.didUpdateLocations(locations)):
///       // Do something cool with user's current location.
///       ...
///
/// Once you have handled all the `CLLocationManagerDelegate` actions you care about, you can ignore
/// the rest:
///
///     case .locationManager:
///       return .none
///
/// And finally, when creating the `Store` to power your application you will supply the "live"
/// implementation of the `LocationManager`, which is an instance that holds onto a
/// `CLLocationManager` on the inside and interacts with it directly:
///
///     let store = Store(
///       initialState: AppState(),
///       reducer: appReducer,
///       environment: AppEnvironment(
///         locationManager: .live,
///         // And your other dependencies...
///       )
///     )
///
/// This is enough to implement a basic application that interacts with Core Location.
///
/// The true power of building your application and interfacing with Core Location in this way is
/// the ability to _test_ how your application interacts with Core Location. It starts by creating
/// a `TestStore` whose environment contains a `.mock` version of the `LocationManager`. The
/// `.mock` function allows you to create a fully controlled version of the location manager that
/// does not interact with `CLLocationManager` at all. Instead, you override whichever endpoints
/// your feature needs to supply deterministic functionality.
///
/// For example, to test the flow of asking for location authorization, being denied, and showing an
/// alert, we need to override the `create` and `requestWhenInUseAuthorization` endpoints. The
/// `create` endpoint needs to return an effect that emits the delegate actions, which we can
/// control via a publish subject. And the `requestWhenInUseAuthorization` endpoint is a
/// fire-and-forget effect, but we can make assertions that it was called how we expect.
///
///     var didRequestInUseAuthorization = false
///     let locationManagerSubject = PassthroughSubject<LocationManager.Action, Never>()
///
///     let store = TestStore(
///       initialState: AppState(),
///       reducer: appReducer,
///       environment: AppEnvironment(
///         locationManager: .mock(
///           create: { _ in locationManagerSubject.eraseToEffect() },
///           requestWhenInUseAuthorization: { _ in
///             .fireAndForget { didRequestInUseAuthorization = true }
///         })
///       )
///     )
///
/// Then we can write an assertion that simulates a sequence of user steps and location manager
/// delegate actions, and we can assert against how state mutates and how effects are received. For
/// example, we can have the user come to the screen, deny the location authorization request, and
/// then assert that an effect was received which caused the alert to show:
///
///     store.assert(
///       .send(.onAppear),
///
///       // Simulate the user denying location access
///       .do {
///         locationManagerSubject.send(.didChangeAuthorization(.denied))
///       },
///
///       // We receive the authorization change delegate action from the effect
///       .receive(.locationManager(.didChangeAuthorization(.denied))) {
///         $0.alert = """
///           Please give location access so that we can show you some cool stuff.
///           """
///       },
///
///       // Store assertions require all effects to be completed, so we complete
///       // the subject manually.
///       .do {
///         locationManagerSubject.send(completion: .finished)
///       }
///     )
///
/// And this is only the tip of the iceberg. We can further test what happens when we are granted
/// authorization by the user and the request for their location returns a specific location that we
/// control, and even what happens when the request for their location fails. It is very easy to
/// write these tests, and we can test deep, subtle properties of our application.
///
public struct LocationManager {

  /// Actions that correspond to `CLLocationManagerDelegate` methods.
  ///
  /// See `CLLocationManagerDelegate` for more information.
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

    @available(macOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    case didRangeBeacons([Beacon], satisfyingConstraint: CLBeaconIdentityConstraint)
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

  var location: (AnyHashable) -> Location? = { _ in _unimplemented("location") }

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

  /// Creates a `CLLocationManager` for the given identifier.
  ///
  /// - Parameter id: A unique identifier for the underlying `CLLocationManager`.
  /// - Returns: An effect of `LocationManager.Action`s.
  public func create(id: AnyHashable) -> Effect<Action, Never> {
    self.create(id)
  }

  /// Tears a `CLLocationManager` down for the given identifier.
  ///
  /// - Parameter id: A unique identifier for the underlying `CLLocationManager`.
  /// - Returns: A fire-and-forget effect.
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

  public func location(id: AnyHashable) -> Location? { self.location(id) }

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

  /// Updates the given properties of a uniquely identified `CLLocationManager`.
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

  /// Updates the given properties of a uniquely identified `CLLocationManager`.
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

  /// Updates the given properties of a uniquely identified `CLLocationManager`.
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

extension LocationManager {
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
    public init(
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
    public init(
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
    public init(
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
