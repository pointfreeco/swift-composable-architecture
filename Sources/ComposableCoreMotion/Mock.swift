import ComposableArchitecture

extension MotionManager {
  public static func mock(
    accelerometerData: @escaping () -> AccelerometerData? = { _unimplemented("accelerometerData") },
    attitudeReferenceFrame: @escaping () -> CMAttitudeReferenceFrame = { _unimplemented("attitudeReferenceFrame") },
    availableAttitudeReferenceFrames: @escaping () -> CMAttitudeReferenceFrame = { _unimplemented("availableAttitudeReferenceFrames") },
    deviceMotion: @escaping () -> DeviceMotion? = { _unimplemented("deviceMotion") },
    gyroData: @escaping () -> GyroData? = { _unimplemented("gyroData") },
    isAccelerometerActive: @escaping () -> Bool = { _unimplemented("isAccelerometerActive") },
    isAccelerometerAvailable: @escaping () -> Bool = { _unimplemented("isAccelerometerAvailable") },
    isDeviceMotionActive: @escaping () -> Bool = { _unimplemented("isDeviceMotionActive") },
    isDeviceMotionAvailable: @escaping () -> Bool = { _unimplemented("isDeviceMotionAvailable") },
    isGyroActive: @escaping () -> Bool = { _unimplemented("isGyroActive") },
    isGyroAvailable: @escaping () -> Bool = { _unimplemented("isGyroAvailable") },
    isMagnetometerActive: @escaping () -> Bool = { _unimplemented("isMagnetometerActive") },
    isMagnetometerAvailable: @escaping () -> Bool = { _unimplemented("isMagnetometerAvailable") },
    magnetometerData: @escaping () -> MagnetometerData? = { _unimplemented("magnetometerData") },
    set: @escaping (MotionManager.Properties) -> Effect<Never, Never> = { _ in _unimplemented("set") },
    startAccelerometerUpdates: @escaping (OperationQueue) -> Effect<AccelerometerData, Error> = { _ in _unimplemented("startAccelerometerUpdates") },
    startDeviceMotionUpdates: @escaping (CMAttitudeReferenceFrame, OperationQueue) -> Effect<DeviceMotion, Error> = { _, _ in _unimplemented("startDeviceMotionUpdates") },
    startGyroUpdates: @escaping (OperationQueue) -> Effect<GyroData, Error> = { _ in _unimplemented("startGyroUpdates") },
    startMagnetometerUpdates: @escaping (OperationQueue) -> Effect<MagnetometerData, Error> = { _ in _unimplemented("startMagnetometerUpdates") },
    stopAccelerometerUpdates: @escaping () -> Effect<Never, Never> = { _unimplemented("stopAccelerometerUpdates") },
    stopDeviceMotionUpdates: @escaping () -> Effect<Never, Never> = { _unimplemented("stopDeviceMotionUpdates") },
    stopGyroUpdates: @escaping () -> Effect<Never, Never> = { _unimplemented("stopGyroUpdates") },
    stopMagnetometerUpdates: @escaping () -> Effect<Never, Never> = { _unimplemented("stopMagnetometerUpdates") }
  ) -> MotionManager {
    Self(
      accelerometerData: accelerometerData,
      attitudeReferenceFrame: attitudeReferenceFrame,
      availableAttitudeReferenceFrames: availableAttitudeReferenceFrames,
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
