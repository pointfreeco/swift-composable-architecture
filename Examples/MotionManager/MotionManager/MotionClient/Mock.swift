import ComposableArchitecture

#if DEBUG
  extension MotionClient {
    static func mock(
      create: @escaping (AnyHashable) -> Effect<Action, Error> = { _ in
        fatalError("Unimplemented")
      },
      startDeviceMotionUpdates: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
        fatalError("Unimplemented")
      },
      stopDeviceMotionUpdates: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
        fatalError("Unimplemented")
      }
    ) -> Self {
      Self(
        create: create,
        startDeviceMotionUpdates: startDeviceMotionUpdates,
        stopDeviceMotionUpdates: stopDeviceMotionUpdates
      )
    }
  }
#endif
