#if canImport(CoreMotion)
  import CoreMotion

  /// A single measurement of the device's rotation rate.
  ///
  /// See the documentation for `CMGyroData` for more info.
  public struct GyroData: Hashable {
    public var rotationRate: CMRotationRate
    public var timestamp: TimeInterval

    public init(_ gyroData: CMGyroData) {
      self.rotationRate = gyroData.rotationRate
      self.timestamp = gyroData.timestamp
    }

    public init(
      rotationRate: CMRotationRate,
      timestamp: TimeInterval
    ) {
      self.rotationRate = rotationRate
      self.timestamp = timestamp
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.rotationRate.x == rhs.rotationRate.x
        && lhs.rotationRate.y == rhs.rotationRate.y
        && lhs.rotationRate.z == rhs.rotationRate.z
        && lhs.timestamp == rhs.timestamp
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(self.rotationRate.x)
      hasher.combine(self.rotationRate.y)
      hasher.combine(self.rotationRate.z)
      hasher.combine(self.timestamp)
    }
  }
#endif
