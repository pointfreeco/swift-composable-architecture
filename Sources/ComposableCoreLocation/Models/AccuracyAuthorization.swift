import CoreLocation
import Foundation

/// A value type wrapper for `CLAccuracyAuthorization`
public enum AccuracyAuthorization: Int {
  case fullAccuracy = 0
  case reducedAccuracy = 1
}

#if os(iOS) || os(tvOS) || os(watchOS) || compiler(>=5.3.1)
@available(iOS 14.0, macCatalyst 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension AccuracyAuthorization {
  init?(_ accuracyAuth: CLAccuracyAuthorization?) {
    switch accuracyAuth {
    case .fullAccuracy:
      self = .fullAccuracy
    case .reducedAccuracy:
      self = .reducedAccuracy
    default:
      return nil
    }
  }
}
#endif
