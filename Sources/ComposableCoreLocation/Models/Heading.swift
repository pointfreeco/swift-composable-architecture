import CoreLocation

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
