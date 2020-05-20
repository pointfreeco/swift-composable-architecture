import CoreLocation

/// A value type wrapper for `CLLocation`. This type is necessary so that we can do equality checks
/// and write tests against its values.
public struct Location: Equatable {
  public let rawValue: CLLocation?

  public var altitude: CLLocationDistance
  public var coordinate: CLLocationCoordinate2D
  public var course: CLLocationDirection

  @available(iOS 13.4, macCatalyst 13.4, macOS 10.15.4, tvOS 13.4, watchOS 6.2, *)
  public var courseAccuracy: CLLocationDirectionAccuracy {
    get { _courseAccuracy } set { _courseAccuracy = newValue }
  }
  private var _courseAccuracy: Double

  public var floor: CLFloor?
  public var horizontalAccuracy: CLLocationAccuracy
  public var speed: CLLocationSpeed

  @available(iOS 13.4, macCatalyst 13.4, macOS 10.15.4, tvOS 13.4, watchOS 6.2, *)
  public var speedAccuracy: CLLocationDirectionAccuracy {
    get { _speedAccuracy } set { _speedAccuracy = newValue }
  }
  private var _speedAccuracy: Double

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
    if #available(iOS 13.4, OSX 10.15.4, macCatalyst 13.4, tvOS 13.4, watchOS 6.2, *) {
      self._courseAccuracy = courseAccuracy
    } else {
      self._courseAccuracy = 0
    }
    self.floor = floor
    self.horizontalAccuracy = horizontalAccuracy
    self.speed = speed
    if #available(iOS 13.4, OSX 10.15.4, macCatalyst 13.4, tvOS 13.4, watchOS 6.2, *) {
      self._speedAccuracy = speedAccuracy
    } else {
      self._speedAccuracy = 0
    }
    self.timestamp = timestamp
    self.verticalAccuracy = verticalAccuracy
  }

  public init(rawValue: CLLocation) {
    self.rawValue = rawValue

    self.altitude = rawValue.altitude
    self.coordinate = rawValue.coordinate
    self.course = rawValue.course
    if #available(iOS 13.4, OSX 10.15.4, macCatalyst 13.4, tvOS 13.4, watchOS 6.2, *) {
      self._courseAccuracy = rawValue.courseAccuracy
    } else {
      self._courseAccuracy = 0
    }
    self.floor = rawValue.floor
    self.horizontalAccuracy = rawValue.horizontalAccuracy
    self.speed = rawValue.speed
    if #available(iOS 13.4, OSX 10.15.4, macCatalyst 13.4, tvOS 13.4, watchOS 6.2, *) {
      self._speedAccuracy = rawValue.speedAccuracy
    } else {
      self._speedAccuracy = 0
    }
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
      && lhs.timestamp == rhs.timestamp
      && lhs.verticalAccuracy == rhs.verticalAccuracy

    if #available(iOS 13.4, OSX 10.15.4, macCatalyst 13.4, tvOS 13.4, watchOS 6.2, *) {
      equals = equals && lhs.courseAccuracy == rhs.courseAccuracy
    }

    if #available(iOS 13.4, OSX 10.15.4, macCatalyst 13.4, tvOS 13.4, watchOS 6.2, *) {
      equals = equals && lhs.speedAccuracy == rhs.speedAccuracy
    }

    return equals
  }
}
