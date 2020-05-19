import CoreLocation

/// A value type wrapper for `CLLocation`. This type is necessary so taht we can do equality checks
/// and write tests against its values.
public struct Location: Equatable {
  public let rawValue: CLLocation?

  public var altitude: CLLocationDistance
  public var coordinate: CLLocationCoordinate2D
  public var course: CLLocationDirection
  public var courseAccuracy: CLLocationDirectionAccuracy
  public var floor: CLFloor?
  public var horizontalAccuracy: CLLocationAccuracy
  public var speed: CLLocationSpeed
  public var speedAccuracy: CLLocationSpeedAccuracy
  public var timestamp: Date
  public var verticalAccuracy: CLLocationAccuracy

  public init(
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
    self.rawValue = nil
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

  public init(rawValue: CLLocation) {
    self.rawValue = rawValue

    self.altitude = rawValue.altitude
    self.coordinate = rawValue.coordinate
    self.course = rawValue.course
    if #available(iOS 13.4, OSX 10.15.4, macCatalyst 13.4, tvOS 13.4, watchOS 6.2, *) {
      self.courseAccuracy = rawValue.courseAccuracy
    } else {
      self.courseAccuracy = 0
    }
    self.floor = rawValue.floor
    self.horizontalAccuracy = rawValue.horizontalAccuracy
    self.speed = rawValue.speed
    self.speedAccuracy = rawValue.speedAccuracy
    self.timestamp = rawValue.timestamp
    self.verticalAccuracy = rawValue.verticalAccuracy
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    var equals =
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
      equals = equals && lhs.courseAccuracy == rhs.courseAccuracy
    }

    return equals
  }
}
