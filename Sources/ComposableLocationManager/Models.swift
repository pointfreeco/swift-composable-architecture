import CoreLocation

public enum LocationManagerAction: Equatable {
  case didChangeAuthorization(CLAuthorizationStatus)
  case didCreate(locationServicesEnabled: Bool, authorizationStatus: CLAuthorizationStatus)
  case didFailWithError(LocationManagerError)
  case didUpdateLocations([Location])
  #if !os(macOS)
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

#if !os(macOS)
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
