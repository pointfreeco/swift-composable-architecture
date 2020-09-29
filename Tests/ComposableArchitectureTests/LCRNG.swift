/// A linear congruential random number generator.
public struct LCRNG: RandomNumberGenerator {
  public var seed: UInt64

  @inlinable
  public init(seed: UInt64) {
    self.seed = seed
  }

  @inlinable
  public mutating func next() -> UInt64 {
    seed = 2_862_933_555_777_941_757 &* seed &+ 3_037_000_493
    return seed
  }
}
