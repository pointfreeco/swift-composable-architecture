import CoreMotion

public struct AccelerometerData: Equatable {
  var acceleration: CMAcceleration

  public init(_ accelerometerData: CMAccelerometerData) {
    self.acceleration = accelerometerData.acceleration
  }

  public init(acceleration: CMAcceleration) {
    self.acceleration = acceleration
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.acceleration.x == rhs.acceleration.x
      && lhs.acceleration.y == rhs.acceleration.y
      && lhs.acceleration.z == rhs.acceleration.z
  }
}
