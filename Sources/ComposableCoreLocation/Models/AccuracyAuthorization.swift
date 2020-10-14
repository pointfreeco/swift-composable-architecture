import CoreLocation
import Foundation

/// A value type wrapper for `CLAccuracyAuthorization`. This type is necessary to have iOS 13 support
public enum AccuracyAuthorization {
  case fullAccuracy
  case reducedAccuracy

  @available(iOS 14, *)
  init?(_ accuracyAuth: CLAccuracyAuthorization?) {
    if accuracyAuth == nil {
      return nil
    } else {
      switch accuracyAuth {
      case .fullAccuracy:
        self = .fullAccuracy
      case .reducedAccuracy:
        self = .reducedAccuracy
      @unknown default:
        return nil
      }
    }
  }
}
