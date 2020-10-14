//
//  File.swift
//
//
//  Created by Jeffrey Macko on 15/10/2020.
//

import CoreLocation
import Foundation

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
