#if canImport(CoreMotion)
  import CoreMotion

  /// Encapsulated measurements of the attitude, rotation rate, and acceleration of a device.
  ///
  /// See the documentation for `CMDeviceMotion` for more info.
  public struct DeviceMotion: Hashable {
    public var attitude: Attitude
    public var gravity: CMAcceleration
    public var heading: Double
    public var magneticField: CMCalibratedMagneticField
    public var rotationRate: CMRotationRate
    public var timestamp: TimeInterval
    public var userAcceleration: CMAcceleration

    public init(_ deviceMotion: CMDeviceMotion) {
      self.attitude = Attitude(deviceMotion.attitude)
      self.gravity = deviceMotion.gravity
      self.heading = deviceMotion.heading
      self.magneticField = deviceMotion.magneticField
      self.rotationRate = deviceMotion.rotationRate
      self.timestamp = deviceMotion.timestamp
      self.userAcceleration = deviceMotion.userAcceleration
    }

    public init(
      attitude: Attitude,
      gravity: CMAcceleration,
      heading: Double,
      magneticField: CMCalibratedMagneticField,
      rotationRate: CMRotationRate,
      timestamp: TimeInterval,
      userAcceleration: CMAcceleration
    ) {
      self.attitude = attitude
      self.gravity = gravity
      self.heading = heading
      self.magneticField = magneticField
      self.rotationRate = rotationRate
      self.timestamp = timestamp
      self.userAcceleration = userAcceleration
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.attitude == rhs.attitude
        && lhs.gravity.x == rhs.gravity.x
        && lhs.gravity.y == rhs.gravity.y
        && lhs.gravity.z == rhs.gravity.z
        && lhs.heading == rhs.heading
        && lhs.magneticField.accuracy == rhs.magneticField.accuracy
        && lhs.magneticField.field.x == rhs.magneticField.field.x
        && lhs.magneticField.field.y == rhs.magneticField.field.y
        && lhs.magneticField.field.z == rhs.magneticField.field.z
        && lhs.rotationRate.x == rhs.rotationRate.x
        && lhs.rotationRate.y == rhs.rotationRate.y
        && lhs.rotationRate.z == rhs.rotationRate.z
        && lhs.timestamp == rhs.timestamp
        && lhs.userAcceleration.x == rhs.userAcceleration.x
        && lhs.userAcceleration.y == rhs.userAcceleration.y
        && lhs.userAcceleration.z == rhs.userAcceleration.z
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(self.attitude)
      hasher.combine(self.gravity.x)
      hasher.combine(self.gravity.y)
      hasher.combine(self.gravity.z)
      hasher.combine(self.heading)
      hasher.combine(self.magneticField.accuracy)
      hasher.combine(self.magneticField.field.x)
      hasher.combine(self.magneticField.field.y)
      hasher.combine(self.magneticField.field.z)
      hasher.combine(self.rotationRate.x)
      hasher.combine(self.rotationRate.y)
      hasher.combine(self.rotationRate.z)
      hasher.combine(self.timestamp)
      hasher.combine(self.userAcceleration.x)
      hasher.combine(self.userAcceleration.y)
      hasher.combine(self.userAcceleration.z)
    }
  }
#endif
