import CoreLocation
import Foundation

/// A value type wrapper for `CLAccuracyAuthorization`. This type is necessary to have iOS 13 support
public enum AccuracyAuthorization: Hashable {
  case fullAccuracy
  case reducedAccuracy

  #if swift(>=5.3)
  @available(iOS 14, macCatalyst 14, macOS 11, tvOS 14, watchOS 7, *)
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
  #endif
}
