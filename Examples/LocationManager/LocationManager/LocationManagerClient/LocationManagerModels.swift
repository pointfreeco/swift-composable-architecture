import CoreLocation
import MapKit

struct Location: Equatable {
  var altitude: CLLocationDistance
  var coordinate: CLLocationCoordinate2D
  var course: CLLocationDirection
  var courseAccuracy: CLLocationDirectionAccuracy
  var floor: CLFloor?
  var horizontalAccuracy: CLLocationAccuracy
  var speed: CLLocationSpeed
  var speedAccuracy: CLLocationSpeedAccuracy
  var timestamp: Date
  var verticalAccuracy: CLLocationAccuracy

  init(
    altitude: CLLocationDistance,
    coordinate: CLLocationCoordinate2D,
    course: CLLocationDirection,
    courseAccuracy: CLLocationDirectionAccuracy,
    floor: CLFloor?,
    horizontalAccuracy: CLLocationAccuracy,
    speed: CLLocationSpeed,
    speedAccuracy: CLLocationSpeedAccuracy,
    timestamp: Date,
    verticalAccuracy: CLLocationAccuracy
  ) {
    self.altitude = altitude
    self.coordinate = coordinate
    self.course = course
    self.courseAccuracy = courseAccuracy
    self.floor = floor
    self.horizontalAccuracy = horizontalAccuracy
    self.speed = speed
    self.speedAccuracy = speedAccuracy
    self.timestamp = timestamp
    self.verticalAccuracy = verticalAccuracy
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    let equals =
      lhs.altitude == rhs.altitude
      && lhs.coordinate.latitude == rhs.coordinate.latitude
      && lhs.coordinate.longitude == rhs.coordinate.longitude
      && lhs.course == rhs.course
      && lhs.floor == rhs.floor
      && lhs.horizontalAccuracy == rhs.horizontalAccuracy
      && lhs.speed == rhs.speed
      && lhs.speedAccuracy == rhs.speedAccuracy
      && lhs.timestamp == rhs.timestamp
      && lhs.verticalAccuracy == rhs.verticalAccuracy

    if #available(iOS 13.4, *) {
      return equals && lhs.courseAccuracy == rhs.courseAccuracy
    } else {
      return equals
    }
  }
}

extension Location {
  init(rawValue: CLLocation) {
    self.altitude = rawValue.altitude
    self.coordinate = rawValue.coordinate
    self.course = rawValue.course
    self.courseAccuracy = rawValue.courseAccuracy
    self.floor = rawValue.floor
    self.horizontalAccuracy = rawValue.horizontalAccuracy
    self.speed = rawValue.speed
    self.speedAccuracy = rawValue.speedAccuracy
    self.timestamp = rawValue.timestamp
    self.verticalAccuracy = rawValue.verticalAccuracy
  }
}

struct CoordinateRegion: Equatable {
  var center: CLLocationCoordinate2D
  var span: MKCoordinateSpan

  init(
    center: CLLocationCoordinate2D,
    span: MKCoordinateSpan
  ) {
    self.center = center
    self.span = span
  }

  init(coordinateRegion: MKCoordinateRegion) {
    self.center = coordinateRegion.center
    self.span = coordinateRegion.span
  }

  var asMKCoordinateRegion: MKCoordinateRegion {
    .init(center: self.center, span: self.span)
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.center.latitude == rhs.center.latitude
      && lhs.center.longitude == rhs.center.longitude
      && lhs.span.latitudeDelta == rhs.span.latitudeDelta
      && lhs.span.longitudeDelta == rhs.span.longitudeDelta
  }
}
