import CoreMotion

public struct Attitude: Equatable {
  public var quaternion: CMQuaternion

  public init(_ attitude: CMAttitude) {
    self.quaternion = attitude.quaternion
  }

  public init(quaternion: CMQuaternion) {
    self.quaternion = quaternion
  }

  public var rotationMatrix: CMRotationMatrix {
    var q: CMQuaternion { self.quaternion }

    let s = 1 / (
      self.quaternion.w * self.quaternion.w
        + self.quaternion.x * self.quaternion.x
        + self.quaternion.y * self.quaternion.y
        + self.quaternion.z * self.quaternion.z
    )

    var matrix = CMRotationMatrix()

    matrix.m11 = 1 - 2 * s * (q.y * q.y + q.z * q.z)
    matrix.m12 = 2 * s * (q.x * q.y - q.z * q.w)
    matrix.m13 = 2 * s * (q.x * q.z + q.y * q.w)

    matrix.m21 = 2 * s * (q.x * q.y + q.z * q.w)
    matrix.m22 = 1 - 2 * s * (q.x * q.x + q.z * q.z)
    matrix.m23 = 2 * s * (q.y * q.z - q.x * q.w)

    matrix.m31 = 2 * s * (q.x * q.z - q.y * q.w)
    matrix.m32 = 2 * s * (q.y * q.z + q.x * q.w)
    matrix.m33 = 1 - 2 * s * (q.x * q.x + q.y * q.y)

    return matrix
  }

  public var roll: Double {
    var q: CMQuaternion { self.quaternion }
    return atan2(
      2 * (q.w * q.x + q.y * q.z),
      1 - 2 * (q.x * q.x + q.y * q.y)
    )
  }

  public var pitch: Double {
    var q: CMQuaternion { self.quaternion }
    let p = 2 * (q.w * q.y - q.z * q.x)
    return p > 1 ? Double.pi / 2
      : p < -1 ? -Double.pi / 2
      : asin(p)
  }

  public var yaw: Double {
    var q: CMQuaternion { self.quaternion }
    return atan2(
      2 * (q.w * q.z + q.x * q.y),
      1 - 2 * (q.y * q.y + q.z * q.z)
    )
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.quaternion.w == rhs.quaternion.w
      && lhs.quaternion.x == rhs.quaternion.x
      && lhs.quaternion.y == rhs.quaternion.y
      && lhs.quaternion.z == rhs.quaternion.z
  }
}
