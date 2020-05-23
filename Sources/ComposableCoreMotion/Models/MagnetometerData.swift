import CoreMotion

public struct MagnetometerData: Equatable {
  public var magneticField: CMMagneticField
  public var timestamp: TimeInterval

  public init(_ magnetometerData: CMMagnetometerData) {
    self.magneticField = magnetometerData.magneticField
    self.timestamp = magnetometerData.timestamp
  }

  public init(
    magneticField: CMMagneticField,
    timestamp: TimeInterval
  ) {
    self.magneticField = magneticField
    self.timestamp = timestamp
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.magneticField.x == rhs.magneticField.x
      && lhs.magneticField.y == rhs.magneticField.y
      && lhs.magneticField.z == rhs.magneticField.z
      && lhs.timestamp == rhs.timestamp
  }
}
