import CoreLocation
import MapKit

public enum LocationManagerAction: Equatable {
  case didChangeAuthorization(CLAuthorizationStatus)
  case didCreate(locationServicesEnabled: Bool, authorizationStatus: CLAuthorizationStatus)
  case didFailWithError(LocationManagerError)
  case didUpdateLocations([Location])
  case didVisit(Visit)
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
    let equals = lhs.rawValue.altitude == rhs.rawValue.altitude
      && lhs.rawValue.coordinate.latitude == rhs.rawValue.coordinate.latitude
      && lhs.rawValue.coordinate.longitude == rhs.rawValue.coordinate.longitude
      && lhs.rawValue.course == rhs.rawValue.course
      && lhs.rawValue.floor == rhs.rawValue.floor
      && lhs.rawValue.horizontalAccuracy == rhs.rawValue.horizontalAccuracy
      && lhs.rawValue.speed == rhs.rawValue.speed
      && lhs.rawValue.speedAccuracy == rhs.rawValue.speedAccuracy
      && lhs.rawValue.timestamp == rhs.rawValue.timestamp
      && lhs.rawValue.verticalAccuracy == rhs.rawValue.verticalAccuracy

    if #available(iOS 13.4, *) {
      return equals && lhs.rawValue.courseAccuracy == rhs.rawValue.courseAccuracy
    } else {
      return equals
    }
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<CLLocation, Value>) -> Value {
    self.rawValue[keyPath: keyPath]
  }
}

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

public struct CoordinateRegion: Equatable {
  public var center: CLLocationCoordinate2D
  public var span: MKCoordinateSpan

  public init(
    center: CLLocationCoordinate2D,
    span: MKCoordinateSpan
  ) {
    self.center = center
    self.span = span
  }

  public init(coordinateRegion: MKCoordinateRegion) {
    self.center = coordinateRegion.center
    self.span = coordinateRegion.span
  }

  public var asMKCoordinateRegion: MKCoordinateRegion {
    .init(center: self.center, span: self.span)
  }

  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.center.latitude == rhs.center.latitude
      && lhs.center.longitude == rhs.center.longitude
      && lhs.span.latitudeDelta == rhs.span.latitudeDelta
      && lhs.span.longitudeDelta == rhs.span.longitudeDelta
  }
}
