import CoreLocation

public enum LocationManagerAction: Equatable {
  case didChangeAuthorization(CLAuthorizationStatus)
  case didCreate(locationServicesEnabled: Bool, authorizationStatus: CLAuthorizationStatus)
  case didFailWithError(LocationManagerError)
  case didUpdateLocations([Location])
  #if os(iOS) || targetEnvironment(macCatalyst)
  case didVisit(Visit)
  #endif
}

public struct LocationManagerError: Error, Equatable {
  public init() {}
}

@dynamicMemberLookup
public struct Location: Equatable {
  public let rawValue: CLLocation

  public init(rawValue: CLLocation) {
    self.rawValue = rawValue
  }

  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue.altitude == rhs.rawValue.altitude
      && lhs.rawValue.coordinate.latitude == rhs.rawValue.coordinate.latitude
      && lhs.rawValue.coordinate.longitude == rhs.rawValue.coordinate.longitude
      && lhs.rawValue.course == rhs.rawValue.course
      // && lhs.rawValue.courseAccuracy == rhs.rawValue.courseAccuracy // iOS 13.4
      && lhs.rawValue.floor == rhs.rawValue.floor
      && lhs.rawValue.horizontalAccuracy == rhs.rawValue.horizontalAccuracy
      && lhs.rawValue.speed == rhs.rawValue.speed
      && lhs.rawValue.speedAccuracy == rhs.rawValue.speedAccuracy
      && lhs.rawValue.timestamp == rhs.rawValue.timestamp
      && lhs.rawValue.verticalAccuracy == rhs.rawValue.verticalAccuracy
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<CLLocation, Value>) -> Value {
    self.rawValue[keyPath: keyPath]
  }
}

#if os(iOS) || targetEnvironment(macCatalyst)
public struct Visit: Equatable {
  var arrivalDate: Date
  var coordinate: CLLocationCoordinate2D
  var departureDate: Date
  var horizontalAccuracy: CLLocationAccuracy

  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.arrivalDate == rhs.arrivalDate
      && lhs.coordinate.latitude == rhs.coordinate.latitude
      && lhs.coordinate.longitude == rhs.coordinate.longitude
      && lhs.departureDate == rhs.departureDate
      && lhs.horizontalAccuracy == rhs.horizontalAccuracy
  }
}

extension Visit {
  public init(visit: CLVisit) {
    self.arrivalDate = visit.arrivalDate
    self.coordinate = visit.coordinate
    self.departureDate = visit.departureDate
    self.horizontalAccuracy = visit.horizontalAccuracy
  }
}
#endif

#if os(iOS) || os(macOS) || os(watchOS) || targetEnvironment(macCatalyst)
public struct Heading: Equatable {
  public let rawValue: CLHeading?

  public var headingAccuracy: CLLocationDirection
  public var magneticHeading: CLLocationDirection
  public var timestamp: Date
  public var trueHeading: CLLocationDirection
  public var x: CLHeadingComponentValue
  public var y: CLHeadingComponentValue
  public var z: CLHeadingComponentValue

  init(rawValue: CLHeading) {
    self.rawValue = rawValue

    self.headingAccuracy = rawValue.headingAccuracy
    self.magneticHeading = rawValue.magneticHeading
    self.timestamp = rawValue.timestamp
    self.trueHeading = rawValue.trueHeading
    self.x = rawValue.x
    self.y = rawValue.y
    self.z = rawValue.z
  }

  init(
    headingAccuracy: CLLocationDirection,
    magneticHeading: CLLocationDirection,
    timestamp: Date,
    trueHeading: CLLocationDirection,
    x: CLHeadingComponentValue,
    y: CLHeadingComponentValue,
    z: CLHeadingComponentValue
  ) {
    self.rawValue = nil

    self.headingAccuracy = headingAccuracy
    self.magneticHeading = magneticHeading
    self.timestamp = timestamp
    self.trueHeading = trueHeading
    self.x = x
    self.y = y
    self.z = z
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.headingAccuracy == rhs.headingAccuracy
      && lhs.magneticHeading == rhs.magneticHeading
      && lhs.timestamp == rhs.timestamp
      && lhs.trueHeading == rhs.trueHeading
      && lhs.x == rhs.x
      && lhs.y == rhs.y
      && lhs.z == rhs.z
  }
}
#endif

public struct Region: Hashable {
  public let rawValue: CLRegion?

  public var identifier: String
  public var notifyOnEntry: Bool
  public var notifyOnExit: Bool

  init(rawValue: CLRegion) {
    self.rawValue = rawValue

    self.identifier = rawValue.identifier
    self.notifyOnEntry = rawValue.notifyOnEntry
    self.notifyOnExit = rawValue.notifyOnExit
  }

  init(
    identifier: String,
    notifyOnEntry: Bool,
    notifyOnExit: Bool
  ) {
    self.rawValue = nil

    self.identifier = identifier
    self.notifyOnEntry = notifyOnEntry
    self.notifyOnExit = notifyOnExit
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.identifier == rhs.identifier
      && lhs.notifyOnEntry == rhs.notifyOnEntry
      && lhs.notifyOnExit == rhs.notifyOnExit
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.identifier)
    hasher.combine(self.notifyOnExit)
    hasher.combine(self.notifyOnEntry)
  }
}
