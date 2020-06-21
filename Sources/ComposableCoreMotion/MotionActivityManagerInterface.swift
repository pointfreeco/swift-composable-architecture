import CoreMotion
import Foundation

public struct MotionActivity: Equatable {
  public var automotive: Bool
  public var confidence: CMMotionActivityConfidence
  public var cycling: Bool
  public var running: Bool
  public var startDate: Date
  public var stationary: Bool
  public var timestamp: TimeInterval
  public var unknown: Bool
  public var walking: Bool

  public init(
    automotive: Bool = false,
    confidence: CMMotionActivityConfidence,
    cycling: Bool = false,
    running: Bool = false,
    startDate: Date,
    stationary: Bool = false,
    timestamp: TimeInterval,
    unknown: Bool = false,
    walking: Bool = false
  ) {
    self.automotive = automotive
    self.confidence = confidence
    self.cycling = cycling
    self.running = running
    self.startDate = startDate
    self.stationary = stationary
    self.timestamp = timestamp
    self.unknown = unknown
    self.walking = walking
  }
}

@available(iOS 7.0, *)
@available(macCatalyst 13.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS 2.0, *)
public struct MotionActivityManager {

  public init(
    isActivityAvailable: @escaping () -> Bool,
    authorizationStatus: @escaping () -> CMAuthorizationStatus,
    startActivityUpdates: @escaping (OperationQueue, CMMotionActivityHandler) -> Effect<MotionActivity?, Never>,
    stopActivityUpdates: @escaping () -> Effect<Never, Never>,
    queryActivityStarting: @escaping (Date, Date, OperationQueue, CMMotionActivityQueryHandler) -> Effect<[MotionActivity]?, Error>
  ) {
    self._isActivityAvailable = isActivityAvailable
    self._authorizationStatus = authorizationStatus
    self._startActivityUpdates = startActivityUpdates
    self._stopActivityUpdates = stopActivityUpdates
    self._queryActivityStarting = queryActivityStarting
  }

  private let _authorizationStatus: () -> CMAuthorizationStatus
  private let _create: (AnyHashable) -> Effect<Never, Never>
  private let _isActivityAvailable: () -> Bool
  private let _queryActivityStarting: (AnyHashable, Date, Date, OperationQueue) -> Effect<[MotionActivity]?, Error>
  private let _startActivityUpdates: (AnyHashable, OperationQueue) -> Effect<MotionActivity?, Never>
  private let _stopActivityUpdates: (AnyHashable) -> Effect<Never, Never>
}

@available(iOS 7.0, *)
@available(macCatalyst 13.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS 2.0, *)
extension MotionActivityManager {
  public static let live = MotionActivityManager(
    isActivityAvailable: CMMotionActivityManager.isActivityAvailable,
    authorizationStatus: CMMotionActivityManager.authorizationStatus,
    startActivityUpdates: { queue in
      .run { subscriber in

      }
  },
    stopActivityUpdates: <#T##() -> Effect<Never, Never>#>,
    queryActivityStarting: <#T##(Date, Date, OperationQueue, ([CMMotionActivity]?, Error?) -> Void) -> Effect<[MotionActivity]?, Error>#>
  )
}
