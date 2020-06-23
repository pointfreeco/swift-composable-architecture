import ComposableArchitecture

@available(iOS 14, *)
@available(macCatalyst 14, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS 7, *)
extension HeadphoneMotionManager {
  public static func mock(
    create: @escaping (AnyHashable) -> Effect<Action, Never> = { _ in _unimplemented("create") },
    destroy: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in _unimplemented("destroy") },
    deviceMotion: @escaping (AnyHashable) -> DeviceMotion? = { _ in _unimplemented("deviceMotion")
    },
    isDeviceMotionActive: @escaping (AnyHashable) -> Bool = { _ in
      _unimplemented("isDeviceMotionActive")
    },
    isDeviceMotionAvailable: @escaping (AnyHashable) -> Bool = { _ in
      _unimplemented("isDeviceMotionAvailable")
    },
    startDeviceMotionUpdates: @escaping (AnyHashable, OperationQueue) ->
      Effect<DeviceMotion, Error> = { _, _ in _unimplemented("startDeviceMotionUpdates") },
    stopDeviceMotionUpdates: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
      _unimplemented("stopDeviceMotionUpdates")
    }
  ) -> HeadphoneMotionManager {
    Self(
      create: create,
      destroy: destroy,
      deviceMotion: deviceMotion,
      isDeviceMotionActive: isDeviceMotionActive,
      isDeviceMotionAvailable: isDeviceMotionAvailable,
      startDeviceMotionUpdates: startDeviceMotionUpdates,
      stopDeviceMotionUpdates: stopDeviceMotionUpdates
    )
  }
}
