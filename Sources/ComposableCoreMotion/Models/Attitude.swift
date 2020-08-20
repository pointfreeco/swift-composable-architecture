#if canImport(CoreMotion)
  import CoreMotion

  /// The device's orientation relative to a known frame of reference at a point in time.
  ///
  /// See the documentation for `CMAttitude` for more info.
  public struct Attitude: Hashable {
    public var quaternion: CMQuaternion

    public init(_ attitude: CMAttitude) {
      self.quaternion = attitude.quaternion
    }

    public init(quaternion: CMQuaternion) {
      self.quaternion = quaternion
    }

    @inlinable
    public func multiply(byInverseOf attitude: Self) -> Self {
      .init(quaternion: self.quaternion.multiplied(by: attitude.quaternion.inverse))
    }

    @inlinable
    public var rotationMatrix: CMRotationMatrix {
      let q = self.quaternion

      let s =
        1
        / (self.quaternion.w * self.quaternion.w
          + self.quaternion.x * self.quaternion.x
          + self.quaternion.y * self.quaternion.y
          + self.quaternion.z * self.quaternion.z)

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

    @inlinable
    public var roll: Double {
      let q = self.quaternion
      return atan2(
        2 * (q.w * q.x + q.y * q.z),
        1 - 2 * (q.x * q.x + q.y * q.y)
      )
    }

    @inlinable
    public var pitch: Double {
      let q = self.quaternion
      let p = 2 * (q.w * q.y - q.z * q.x)
      return p > 1
        ? Double.pi / 2
        : p < -1
          ? -Double.pi / 2
          : asin(p)
    }

    @inlinable
    public var yaw: Double {
      let q = self.quaternion
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

    public func hash(into hasher: inout Hasher) {
      hasher.combine(self.quaternion.w)
      hasher.combine(self.quaternion.x)
      hasher.combine(self.quaternion.y)
      hasher.combine(self.quaternion.z)
    }
  }

  extension CMQuaternion {
    @usableFromInline
    var inverse: CMQuaternion {
      let invSumOfSquares =
        1 / (self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w)
      return CMQuaternion(
        x: -self.x * invSumOfSquares,
        y: -self.y * invSumOfSquares,
        z: -self.z * invSumOfSquares,
        w: self.w * invSumOfSquares
      )
    }

    @usableFromInline
    func multiplied(by other: Self) -> Self {
      var result = self
      result.w = self.w * other.w - self.x * other.x - self.y * other.y - self.z * other.z
      result.x = self.w * other.x + self.x * other.w + self.y * other.z - self.z * other.y
      result.y = self.w * other.y - self.x * other.z + self.y * other.w + self.z * other.x
      result.z = self.w * other.z + self.x * other.y - self.y * other.x + self.z * other.w
      return result
    }
  }
#endif
