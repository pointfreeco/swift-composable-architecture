import Combine
import ComposableArchitecture
import CoreLocation

public struct LocationManagerClient {

  public enum Action: Equatable {
    case didChangeAuthorization(CLAuthorizationStatus)
    case didCreate(locationServicesEnabled: Bool, authorizationStatus: CLAuthorizationStatus)
    #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    case didDetermineState(CLRegionState, region: Region)
    #endif
    #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    case didEnterRegion(Region)
    #endif
    #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    case didExitRegion(Region)
    #endif
    #if os(iOS) || targetEnvironment(macCatalyst)
    case didFailRanging(beaconConstraint: CLBeaconIdentityConstraint, error: Error)
    #endif
    case didFailWithError(Error)
    #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    case didFinishDeferredUpdatesWithError(Error)
    #endif
    #if os(iOS) || targetEnvironment(macCatalyst)
    case didPauseLocationUpdates
    #endif
    #if os(iOS) || targetEnvironment(macCatalyst)
    case didRange(beacons: [Beacon], beaconConstraint: CLBeaconIdentityConstraint)
    #endif
    #if os(iOS) || targetEnvironment(macCatalyst)
    case didResumeLocationUpdates
    #endif
    #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    case didStartMonitoring(region: Region)
    #endif
    #if os(iOS) || os(watchOS) || targetEnvironment(macCatalyst)
    case didUpdateHeading(newHeading: Heading)
    #endif
    case didUpdateLocations([Location])
    #if os(iOS)
    case didUpdateTo(newLocation: Location, oldLocation: Location)
    #endif
    #if os(iOS) || targetEnvironment(macCatalyst)
    case didVisit(Visit)
    #endif
    #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    case monitoringDidFail(region: Region?, error: Error)
    #endif
  }

  public struct Error: Swift.Error, Equatable {
    public init() {}
  }

  public var authorizationStatus: () -> CLAuthorizationStatus
  var create: (_ id: AnyHashable) -> Effect<Action, Never>
  var destroy: (AnyHashable) -> Effect<Never, Never>
  #if os(iOS) || os(watchOS) || targetEnvironment(macCatalyst)
  var dismissHeadingCalibrationDisplay: (AnyHashable) -> Effect<Never, Never>
  #endif
  #if os(iOS) || os(watchOS) || targetEnvironment(macCatalyst)
  var heading: (AnyHashable) -> Heading?
  #endif
  #if os(iOS) || os(macOS) || os(watchOS) || targetEnvironment(macCatalyst)
  public var headingAvailable: () -> Bool
  #endif
  #if os(iOS) || targetEnvironment(macCatalyst)
  public var isRangingAvailable: () -> Bool
  #endif
  var location: (AnyHashable) -> Location
  public var locationServicesEnabled: () -> Bool
  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
  var maximumRegionMonitoringDistance: (AnyHashable) -> CLLocationDistance
  #endif
  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
  var monitoredRegions: (AnyHashable) -> Set<Region>
  #endif
  var requestLocation: (AnyHashable) -> Effect<Never, Never>
  #if os(iOS) || os(macOS) || os(watchOS) || targetEnvironment(macCatalyst)
  var requestAlwaysAuthorization: (AnyHashable) -> Effect<Never, Never>
  #endif
  #if os(iOS) || os(tvOS) || os(watchOS) || targetEnvironment(macCatalyst)
  var requestWhenInUseAuthorization: (AnyHashable) -> Effect<Never, Never>
  #endif
  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
  public var significantLocationChangeMonitoringAvailable: () -> Bool
  #endif
  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
  var startMonitoringForRegion: (AnyHashable, Region) -> Effect<Never, Never>
  #endif
  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
  var startMonitoringSignificantLocationChanges: (AnyHashable) -> Effect<Never, Never>
  #endif
  #if os(iOS) || targetEnvironment(macCatalyst)
  var startMonitoringVisits: (AnyHashable) -> Effect<Never, Never>
  #endif
  #if os(iOS) || os(macOS) || os(watchOS) || targetEnvironment(macCatalyst)
  var startUpdatingLocation: (AnyHashable) -> Effect<Never, Never>
  #endif
  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
  var stopMonitoringForRegion: (AnyHashable, Region) -> Effect<Never, Never>
  #endif
  #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
  var stopMonitoringSignificantLocationChanges: (AnyHashable) -> Effect<Never, Never>
  #endif
  #if os(iOS) || targetEnvironment(macCatalyst)
  var stopMonitoringVisits: (AnyHashable) -> Effect<Never, Never>
  #endif
  #if os(iOS) || os(macOS) || os(watchOS) || targetEnvironment(macCatalyst)
  var startUpdatingHeading: (AnyHashable) -> Effect<Never, Never>
  #endif
  #if os(iOS) || os(macOS) || os(watchOS) || targetEnvironment(macCatalyst)
  var stopUpdatingHeading: (AnyHashable) -> Effect<Never, Never>
  #endif
  var stopUpdatingLocation: (AnyHashable) -> Effect<Never, Never>
  var update: (_ id: AnyHashable, _ properties: Properties) -> Effect<Never, Never>

  public func create(id: AnyHashable) -> Effect<Action, Never> {
    self.create(id)
  }

  public func destroy(id: AnyHashable) -> Effect<Never, Never> {
    self.destroy(id)
  }

  public func requestLocation(id: AnyHashable) -> Effect<Never, Never> {
    self.requestLocation(id)
  }

  #if os(iOS) || os(macOS) || os(watchOS) || targetEnvironment(macCatalyst)
  public func requestAlwaysAuthorization(id: AnyHashable) -> Effect<Never, Never> {
    self.requestAlwaysAuthorization(id)
  }
  #endif

  #if os(iOS) || os(tvOS) || os(watchOS) || targetEnvironment(macCatalyst)
  public func requestWhenInUseAuthorization(id: AnyHashable) -> Effect<Never, Never> {
    self.requestWhenInUseAuthorization(id)
  }
  #endif

  #if os(iOS) || targetEnvironment(macCatalyst)
  public func startMonitoringVisits(id: AnyHashable) -> Effect<Never, Never> {
    self.startMonitoringVisits(id)
  }
  #endif

  #if os(iOS) || os(macOS) || os(watchOS) || targetEnvironment(macCatalyst)
  public func startUpdatingLocation(id: AnyHashable) -> Effect<Never, Never> {
    self.startUpdatingLocation(id)
  }
  #endif

  #if os(iOS) || targetEnvironment(macCatalyst)
  public func stopMonitoringVisits(id: AnyHashable) -> Effect<Never, Never> {
    self.stopMonitoringVisits(id)
  }
  #endif

  public func stopUpdatingLocation(id: AnyHashable) -> Effect<Never, Never> {
    self.stopUpdatingLocation(id)
  }

  #if os(iOS) || targetEnvironment(macCatalyst)
  public func __update(
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
    self.update(
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
  #elseif os(macOS) || os(tvOS)
  public func update(
    id: AnyHashable,
    desiredAccuracy: CLLocationAccuracy? = nil,
    distanceFilter: CLLocationDistance? = nil
  ) -> Effect<Never, Never> {
    self.update(
      id,
      Properties(
        desiredAccuracy: desiredAccuracy,
        distanceFilter: distanceFilter
      )
    )
  }
  #elseif os(watchOS)
  public func __update(
    id: AnyHashable,
    activityType: CLActivityType? = nil,
    allowsBackgroundLocationUpdates: Bool? = nil,
    desiredAccuracy: CLLocationAccuracy? = nil,
    distanceFilter: CLLocationDistance? = nil,
    headingFilter: CLLocationDegrees? = nil,
    headingOrientation: CLDeviceOrientation? = nil
  ) -> Effect<Never, Never> {
    self.update(
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
  #endif
}

extension LocationManagerClient {
  init() {
    self.authorizationStatus = { fatalError() }
    self.create = { _ in fatalError() }
    self.destroy = { _ in fatalError() }
    #if os(iOS) || os(watchOS) || targetEnvironment(macCatalyst)
    self.dismissHeadingCalibrationDisplay = { _ in fatalError() }
    #endif
    #if os(iOS) || os(watchOS) || targetEnvironment(macCatalyst)
    self.heading = { _ in fatalError() }
    #endif
    #if os(iOS) || os(macOS) || os(watchOS) || targetEnvironment(macCatalyst)
    self.headingAvailable = { fatalError() }
    #endif
    #if os(iOS) || targetEnvironment(macCatalyst)
    self.isRangingAvailable = { fatalError() }
    #endif
    self.location = { _ in fatalError() }
    self.locationServicesEnabled = { fatalError() }
    #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    self.maximumRegionMonitoringDistance = { _ in fatalError() }
    #endif
    #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    self.monitoredRegions = { _ in fatalError() }
    #endif
    self.requestLocation = { _ in fatalError() }
    #if os(iOS) || os(macOS) || os(watchOS) || targetEnvironment(macCatalyst)
    self.requestAlwaysAuthorization = { _ in fatalError() }
    #endif
    #if os(iOS) || os(tvOS) || os(watchOS) || targetEnvironment(macCatalyst)
    self.requestWhenInUseAuthorization = { _ in fatalError() }
    #endif
    #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    self.significantLocationChangeMonitoringAvailable = { fatalError() }
    #endif
    #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    self.startMonitoringForRegion = { _, _ in fatalError() }
    #endif
    #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    self.startMonitoringSignificantLocationChanges = { _ in fatalError() }
    #endif
    #if os(iOS) || targetEnvironment(macCatalyst)
    self.startMonitoringVisits = { _ in fatalError() }
    #endif
    #if os(iOS) || os(macOS) || os(watchOS) || targetEnvironment(macCatalyst)
    self.startUpdatingLocation = { _ in fatalError() }
    #endif
    #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    self.stopMonitoringForRegion = { _, _ in fatalError() }
    #endif
    #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    self.stopMonitoringSignificantLocationChanges = { _ in fatalError() }
    #endif
    #if os(iOS) || targetEnvironment(macCatalyst)
    self.stopMonitoringVisits = { _ in fatalError() }
    #endif
    #if os(iOS) || os(macOS) || os(watchOS) || targetEnvironment(macCatalyst)
    self.startUpdatingHeading = { _ in fatalError() }
    #endif
    #if os(iOS) || os(macOS) || os(watchOS) || targetEnvironment(macCatalyst)
    self.stopUpdatingHeading = { _ in fatalError() }
    #endif
    self.stopUpdatingLocation = { _ in fatalError() }
    self.update = { _, _ in fatalError() }
  }
}

extension LocationManagerClient {
  public struct Properties {
    #if os(iOS) || os(watchOS) || targetEnvironment(macCatalyst)
    let activityType: CLActivityType?
    let allowsBackgroundLocationUpdates: Bool?
    #endif
    #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || targetEnvironment(macCatalyst)
    let desiredAccuracy: CLLocationAccuracy?
    let distanceFilter: CLLocationDistance?
    #if os(iOS) || os(watchOS) || targetEnvironment(macCatalyst)
    var headingFilter: CLLocationDegrees?
    var headingOrientation: CLDeviceOrientation?
    #endif
    #endif
    #if os(iOS) || targetEnvironment(macCatalyst)
    let pausesLocationUpdatesAutomatically: Bool?
    let showsBackgroundLocationIndicator: Bool?
    #endif

    #if os(iOS) || targetEnvironment(macCatalyst)
    public init(
      activityType: CLActivityType?,
      allowsBackgroundLocationUpdates: Bool?,
      desiredAccuracy: CLLocationAccuracy?,
      distanceFilter: CLLocationDistance?,
      headingFilter: CLLocationDegrees?,
      headingOrientation: CLDeviceOrientation?,
      pausesLocationUpdatesAutomatically: Bool?,
      showsBackgroundLocationIndicator: Bool?
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
    #elseif os(macOS) || os(tvOS)
    public init(
      desiredAccuracy: CLLocationAccuracy?,
      distanceFilter: CLLocationDistance?
    ) {
      self.desiredAccuracy = desiredAccuracy
      self.distanceFilter = distanceFilter
    }
    #elseif os(watchOS)
    public init(
      activityType: CLActivityType?,
      allowsBackgroundLocationUpdates: Bool?,
      desiredAccuracy: CLLocationAccuracy?,
      distanceFilter: CLLocationDistance?,
      headingFilter: CLLocationDegrees?,
      headingOrientation: CLDeviceOrientation?
    ) {
      self.activityType = activityType
      self.allowsBackgroundLocationUpdates = allowsBackgroundLocationUpdates
      self.desiredAccuracy = desiredAccuracy
      self.distanceFilter = distanceFilter
      self.headingFilter = headingFilter
      self.headingOrientation = headingOrientation
    }
    #endif
  }
}
