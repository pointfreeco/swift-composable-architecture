import CoreMotion

public struct DeviceMotion: Equatable {
  public var gravity: CMAcceleration
  public var userAcceleration: CMAcceleration

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.gravity.x == rhs.gravity.x
      && lhs.gravity.y == rhs.gravity.y
      && lhs.gravity.z == rhs.gravity.z
      && lhs.userAcceleration.x == rhs.userAcceleration.x
      && lhs.userAcceleration.y == rhs.userAcceleration.y
      && lhs.userAcceleration.z == rhs.userAcceleration.z
  }
}

extension DeviceMotion {
  public init(deviceMotion: CMDeviceMotion) {
    self.gravity = deviceMotion.gravity
    self.userAcceleration = deviceMotion.userAcceleration
  }
}
