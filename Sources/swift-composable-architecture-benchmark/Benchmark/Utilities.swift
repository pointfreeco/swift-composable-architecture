import Foundation
#if canImport(Accelerate)
  import Accelerate
#endif

extension Array where Element == Double {
  var meanAndStandardDeviation: (mean: Double, stdDev: Double)? {
    guard !isEmpty else { return nil }
    guard count > 1 else { return (first!, 0) }

    var mean = 0.0
    var stdDev = 0.0

    #if canImport(Accelerate)
      vDSP_normalizeD(self, 1, nil, 1, &mean, &stdDev, vDSP_Length(count))
      stdDev *= sqrt(Double(count) / Double(count - 1))
    #else
      mean = reduce(0, +) / Double(count)
      stdDev = sqrt(reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(count - 1))
    #endif
    return (mean, stdDev)
  }
}

func timestampInNanoseconds() -> UInt64 {
  clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
}

func seconds(t1: UInt64, t2: UInt64) -> TimeInterval {
  Double(t2 - t1) * 1e-9
}
