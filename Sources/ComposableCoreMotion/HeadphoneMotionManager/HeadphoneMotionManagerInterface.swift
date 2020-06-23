import ComposableArchitecture
import CoreMotion

/// A wrapper around Core Motion's `CMHeadphoneMotionManager` that exposes its functionality through
/// effects and actions, making it easy to use with the Composable Architecture, and easy to test.
@available(iOS 14, *)
@available(macCatalyst 14, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS 7, *)
public struct HeadphoneMotionManager {

  /// Actions that correspond to `CMHeadphoneMotionManagerDelegate` methods.
  ///
  /// See `CMHeadphoneMotionManagerDelegate` for more information.
  public enum Action: Equatable {
    case didConnect
    case didDisconnect
  }

  /// Creates a headphone motion manager.
  ///
  /// A motion manager must be first created before you can use its functionality, such as starting
  /// device motion updates or accessing data directly from the manager.
  public func create(id: AnyHashable) -> Effect<Action, Never> {
    self.create(id)
  }

  /// Destroys a currently running headphone motion manager.
  ///
  /// In is good practice to destroy a headphone motion manager once you are done with it, such as
  /// when you leave a screen or no longer need motion data.
  public func destroy(id: AnyHashable) -> Effect<Never, Never> {
    self.destroy(id)
  }

  /// The latest sample of device-motion data.
  public func deviceMotion(id: AnyHashable) -> DeviceMotion? {
    self.deviceMotion(id)
  }

  /// A Boolean value that determines whether the app is receiving updates from the device-motion
  /// service.
  public func isDeviceMotionActive(id: AnyHashable) -> Bool {
    self.isDeviceMotionActive(id)
  }

  /// A Boolean value that indicates whether the device-motion service is available on the device.
  public func isDeviceMotionAvailable(id: AnyHashable) -> Bool {
    self.isDeviceMotionAvailable(id)
  }

  /// Starts device-motion updates without a block handler.
  ///
  /// Returns a long-living effect that emits device motion data each time the headphone motion
  /// manager receives a new value.
  public func startDeviceMotionUpdates(
    id: AnyHashable,
    to queue: OperationQueue = .main
  ) -> Effect<DeviceMotion, Error> {
    self.startDeviceMotionUpdates(id, queue)
  }

  /// Stops device-motion updates.
  public func stopDeviceMotionUpdates(id: AnyHashable) -> Effect<Never, Never> {
    self.stopDeviceMotionUpdates(id)
  }

  public init(
    create: @escaping (AnyHashable) -> Effect<Action, Never>,
    destroy: @escaping (AnyHashable) -> Effect<Never, Never>,
    deviceMotion: @escaping (AnyHashable) -> DeviceMotion?,
    isDeviceMotionActive: @escaping (AnyHashable) -> Bool,
    isDeviceMotionAvailable: @escaping (AnyHashable) -> Bool,
    startDeviceMotionUpdates: @escaping (AnyHashable, OperationQueue) ->
      Effect<DeviceMotion, Error>,
    stopDeviceMotionUpdates: @escaping (AnyHashable) -> Effect<Never, Never>
  ) {
    self.create = create
    self.destroy = destroy
    self.deviceMotion = deviceMotion
    self.isDeviceMotionActive = isDeviceMotionActive
    self.isDeviceMotionAvailable = isDeviceMotionAvailable
    self.startDeviceMotionUpdates = startDeviceMotionUpdates
    self.stopDeviceMotionUpdates = stopDeviceMotionUpdates
  }

  var create: (AnyHashable) -> Effect<Action, Never>
  var destroy: (AnyHashable) -> Effect<Never, Never>
  var deviceMotion: (AnyHashable) -> DeviceMotion?
  var isDeviceMotionActive: (AnyHashable) -> Bool
  var isDeviceMotionAvailable: (AnyHashable) -> Bool
  var startDeviceMotionUpdates: (AnyHashable, OperationQueue) -> Effect<DeviceMotion, Error>
  var stopDeviceMotionUpdates: (AnyHashable) -> Effect<Never, Never>
}
