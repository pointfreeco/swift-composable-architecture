import ComposableArchitecture

extension MotionManager {
  public static func mock(
    accelerometerData: @escaping () -> AccelerometerData? = { _unimplemented("") },
    attitudeReferenceFrame: @escaping () -> CMAttitudeReferenceFrame = { _unimplemented("") },
    availableAttitudeReferenceFrames: @escaping () -> CMAttitudeReferenceFrame = { _unimplemented("") },
    deviceMotion: @escaping () -> DeviceMotion? = { _unimplemented("") },
    gyroData: @escaping () -> GyroData? = { _unimplemented("") },
    isAccelerometerActive: @escaping () -> Bool = { _unimplemented("") },
    isAccelerometerAvailable: @escaping () -> Bool = { _unimplemented("") },
    isDeviceMotionActive: @escaping () -> Bool = { _unimplemented("") },
    isDeviceMotionAvailable: @escaping () -> Bool = { _unimplemented("") },
    isGyroActive: @escaping () -> Bool = { _unimplemented("") },
    isGyroAvailable: @escaping () -> Bool = { _unimplemented("") },
    isMagnetometerActive: @escaping () -> Bool = { _unimplemented("") },
    isMagnetometerAvailable: @escaping () -> Bool = { _unimplemented("") },
    magnetometerData: @escaping () -> MagnetometerData? = { _unimplemented("") },
    set: @escaping (MotionManager.Properties) -> Effect<Never, Never> = { _ in _unimplemented("") },
    startAccelerometerUpdates: @escaping (OperationQueue) -> Effect<AccelerometerData, Error> = { _ in _unimplemented("") },
    startDeviceMotionUpdates: @escaping (CMAttitudeReferenceFrame, OperationQueue) -> Effect<DeviceMotion, Error> = { _, _ in _unimplemented("") },
    startGyroUpdates: @escaping (OperationQueue) -> Effect<GyroData, Error> = { _ in _unimplemented("") },
    startMagnetometerUpdates: @escaping (OperationQueue) -> Effect<MagnetometerData, Error> = { _ in _unimplemented("") },
    stopAccelerometerUpdates: @escaping () -> Effect<Never, Never> = { _unimplemented("") },
    stopDeviceMotionUpdates: @escaping () -> Effect<Never, Never> = { _unimplemented("") },
    stopGyroUpdates: @escaping () -> Effect<Never, Never> = { _unimplemented("") },
    stopMagnetometerUpdates: @escaping () -> Effect<Never, Never> = { _unimplemented("") }
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
