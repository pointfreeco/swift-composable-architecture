#if canImport(CoreMotion)
  import ComposableArchitecture

  @available(iOS 4.0, *)
  @available(macCatalyst 13.0, *)
  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS 2.0, *)
  extension MotionManager {
    public static func mock(
      accelerometerData: @escaping (AnyHashable) -> AccelerometerData? = { _ in
        _unimplemented("accelerometerData")
      },
      attitudeReferenceFrame: @escaping (AnyHashable) -> CMAttitudeReferenceFrame = { _ in
        _unimplemented("attitudeReferenceFrame")
      },
      availableAttitudeReferenceFrames: @escaping () -> CMAttitudeReferenceFrame = {
        _unimplemented("availableAttitudeReferenceFrames")
      },
      create: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in _unimplemented("create") },
      destroy: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in _unimplemented("destroy") },
      deviceMotion: @escaping (AnyHashable) -> DeviceMotion? = { _ in _unimplemented("deviceMotion")
      },
      gyroData: @escaping (AnyHashable) -> GyroData? = { _ in _unimplemented("gyroData") },
      isAccelerometerActive: @escaping (AnyHashable) -> Bool = { _ in
        _unimplemented("isAccelerometerActive")
      },
      isAccelerometerAvailable: @escaping (AnyHashable) -> Bool = { _ in
        _unimplemented("isAccelerometerAvailable")
      },
      isDeviceMotionActive: @escaping (AnyHashable) -> Bool = { _ in
        _unimplemented("isDeviceMotionActive")
      },
      isDeviceMotionAvailable: @escaping (AnyHashable) -> Bool = { _ in
        _unimplemented("isDeviceMotionAvailable")
      },
      isGyroActive: @escaping (AnyHashable) -> Bool = { _ in _unimplemented("isGyroActive") },
      isGyroAvailable: @escaping (AnyHashable) -> Bool = { _ in _unimplemented("isGyroAvailable") },
      isMagnetometerActive: @escaping (AnyHashable) -> Bool = { _ in
        _unimplemented("isMagnetometerActive")
      },
      isMagnetometerAvailable: @escaping (AnyHashable) -> Bool = { _ in
        _unimplemented("isMagnetometerAvailable")
      },
      magnetometerData: @escaping (AnyHashable) -> MagnetometerData? = { _ in
        _unimplemented("magnetometerData")
      },
      set: @escaping (AnyHashable, MotionManager.Properties) -> Effect<Never, Never> = { _, _ in
        _unimplemented("set")
      },
      startAccelerometerUpdates: @escaping (AnyHashable, OperationQueue) -> Effect<
        AccelerometerData, Error
      > = { _, _ in _unimplemented("startAccelerometerUpdates") },
      startDeviceMotionUpdates: @escaping (AnyHashable, CMAttitudeReferenceFrame, OperationQueue) ->
        Effect<DeviceMotion, Error> = { _, _, _ in _unimplemented("startDeviceMotionUpdates") },
      startGyroUpdates: @escaping (AnyHashable, OperationQueue) -> Effect<GyroData, Error> = {
        _, _ in
        _unimplemented("startGyroUpdates")
      },
      startMagnetometerUpdates: @escaping (AnyHashable, OperationQueue) -> Effect<
        MagnetometerData, Error
      > = { _, _ in _unimplemented("startMagnetometerUpdates") },
      stopAccelerometerUpdates: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
        _unimplemented("stopAccelerometerUpdates")
      },
      stopDeviceMotionUpdates: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
        _unimplemented("stopDeviceMotionUpdates")
      },
      stopGyroUpdates: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
        _unimplemented("stopGyroUpdates")
      },
      stopMagnetometerUpdates: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
        _unimplemented("stopMagnetometerUpdates")
      }
    ) -> MotionManager {
      Self(
        accelerometerData: accelerometerData,
        attitudeReferenceFrame: attitudeReferenceFrame,
        availableAttitudeReferenceFrames: availableAttitudeReferenceFrames,
        create: create,
        destroy: destroy,
        deviceMotion: deviceMotion,
        gyroData: gyroData,
        isAccelerometerActive: isAccelerometerActive,
        isAccelerometerAvailable: isAccelerometerAvailable,
        isDeviceMotionActive: isDeviceMotionActive,
        isDeviceMotionAvailable: isDeviceMotionAvailable,
        isGyroActive: isGyroActive,
        isGyroAvailable: isGyroAvailable,
        isMagnetometerActive: isMagnetometerActive,
        isMagnetometerAvailable: isMagnetometerAvailable,
        magnetometerData: magnetometerData,
        set: set,
        startAccelerometerUpdates: startAccelerometerUpdates,
        startDeviceMotionUpdates: startDeviceMotionUpdates,
        startGyroUpdates: startGyroUpdates,
        startMagnetometerUpdates: startMagnetometerUpdates,
        stopAccelerometerUpdates: stopAccelerometerUpdates,
        stopDeviceMotionUpdates: stopDeviceMotionUpdates,
        stopGyroUpdates: stopGyroUpdates,
        stopMagnetometerUpdates: stopMagnetometerUpdates
      )
    }
  }

  public func _unimplemented(
    _ function: StaticString, file: StaticString = #file, line: UInt = #line
  ) -> Never {
    fatalError(
      """
      `\(function)` was called but is not implemented. Be sure to provide an implementation for
      this endpoint when creating the mock.
      """,
      file: file,
      line: line
    )
  }
#endif
