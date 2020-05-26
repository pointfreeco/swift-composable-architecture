import ComposableArchitecture
import CoreMotion

@available(iOS 4.0, *)
@available(macCatalyst 13.0, *)
@available(watchOS 2.0, *)
public struct MotionManager {
  public struct Error: Swift.Error, Equatable {
    public var rawValue: CMError

    public init(_ error: Swift.Error) {
      self.rawValue = CMError(UInt32((error as NSError).code))
    }
  }

  public func accelerometerData(id: AnyHashable) -> AccelerometerData? {
    self._accelerometerData(id)
  }

  public func attitudeReferenceFrame(id: AnyHashable) -> CMAttitudeReferenceFrame {
    self._attitudeReferenceFrame(id)
  }

  public func availableAttitudeReferenceFrames() -> CMAttitudeReferenceFrame {
    self._availableAttitudeReferenceFrames()
  }

  public func deviceMotion(id: AnyHashable) -> DeviceMotion? {
    self._deviceMotion(id)
  }

  public func gyroData(id: AnyHashable) -> GyroData? {
    self._gyroData(id)
  }

  public func isAccelerometerActive(id: AnyHashable) -> Bool {
    self._isAccelerometerActive(id)
  }

  public func isAccelerometerAvailable(id: AnyHashable) -> Bool {
    self._isAccelerometerAvailable(id)
  }

  public func isDeviceMotionActive(id: AnyHashable) -> Bool {
    self._isDeviceMotionActive(id)
  }

  public func isDeviceMotionAvailable(id: AnyHashable) -> Bool {
    self._isDeviceMotionAvailable(id)
  }

  public func isGyroActive(id: AnyHashable) -> Bool {
    self._isGyroActive(id)
  }

  public func isGyroAvailable(id: AnyHashable) -> Bool {
    self._isGyroAvailable(id)
  }

  public func isMagnetometerActive(id: AnyHashable) -> Bool {
    self._isMagnetometerActive(id)
  }

  public func isMagnetometerAvailable(id: AnyHashable) -> Bool {
    self._isMagnetometerAvailable(id)
  }

  public func magnetometerData(id: AnyHashable) -> MagnetometerData? {
    self._magnetometerData(id)
  }

  public func set(id: AnyHashable, properties: Properties) -> Effect<Never, Never> {
    self._set(id, properties)
  }

  public func startAccelerometerUpdates(
    id: AnyHashable,
    to queue: OperationQueue = .main
  ) -> Effect<AccelerometerData, Error> {
    self._startAccelerometerUpdates(id, queue)
  }

  public func startDeviceMotionUpdates(
    id: AnyHashable,
    using referenceFrame: CMAttitudeReferenceFrame,
    to queue: OperationQueue = .main
  ) -> Effect<DeviceMotion, Error> {
    self._startDeviceMotionUpdates(id, referenceFrame, queue)
  }

  public func startGyroUpdates(
    id: AnyHashable,
    to queue: OperationQueue = .main
  ) -> Effect<GyroData, Error> {
    self._startGyroUpdates(id, queue)
  }

  public func startMagnetometerUpdates(
    id: AnyHashable,
    to queue: OperationQueue = .main
  ) -> Effect<MagnetometerData, Error> {
    self._startMagnetometerUpdates(id, queue)
  }

  public func stopAccelerometerUpdates(id: AnyHashable) -> Effect<Never, Never> {
    self._stopAccelerometerUpdates(id)
  }

  public func stopDeviceMotionUpdates(id: AnyHashable) -> Effect<Never, Never> {
    self._stopDeviceMotionUpdates(id)
  }

  public func stopGyroUpdates(id: AnyHashable) -> Effect<Never, Never> {
    self._stopGyroUpdates(id)
  }

  public func stopMagnetometerUpdates(id: AnyHashable) -> Effect<Never, Never> {
    self._stopMagnetometerUpdates(id)
  }

  public init(
    accelerometerData: @escaping (AnyHashable) -> AccelerometerData?,
    attitudeReferenceFrame: @escaping (AnyHashable) -> CMAttitudeReferenceFrame,
    availableAttitudeReferenceFrames: @escaping () -> CMAttitudeReferenceFrame,
    deviceMotion: @escaping (AnyHashable) -> DeviceMotion?,
    gyroData: @escaping (AnyHashable) -> GyroData?,
    isAccelerometerActive: @escaping (AnyHashable) -> Bool,
    isAccelerometerAvailable: @escaping (AnyHashable) -> Bool,
    isDeviceMotionActive: @escaping (AnyHashable) -> Bool,
    isDeviceMotionAvailable: @escaping (AnyHashable) -> Bool,
    isGyroActive: @escaping (AnyHashable) -> Bool,
    isGyroAvailable: @escaping (AnyHashable) -> Bool,
    isMagnetometerActive: @escaping (AnyHashable) -> Bool,
    isMagnetometerAvailable: @escaping (AnyHashable) -> Bool,
    magnetometerData: @escaping (AnyHashable) -> MagnetometerData?,
    set: @escaping (AnyHashable, MotionManager.Properties) -> Effect<Never, Never>,
    startAccelerometerUpdates: @escaping (AnyHashable, OperationQueue) -> Effect<
      AccelerometerData, Error
    >,
    startDeviceMotionUpdates: @escaping (AnyHashable, CMAttitudeReferenceFrame, OperationQueue) ->
      Effect<DeviceMotion, Error>,
    startGyroUpdates: @escaping (AnyHashable, OperationQueue) -> Effect<GyroData, Error>,
    startMagnetometerUpdates: @escaping (AnyHashable, OperationQueue) -> Effect<
      MagnetometerData, Error
    >,
    stopAccelerometerUpdates: @escaping (AnyHashable) -> Effect<Never, Never>,
    stopDeviceMotionUpdates: @escaping (AnyHashable) -> Effect<Never, Never>,
    stopGyroUpdates: @escaping (AnyHashable) -> Effect<Never, Never>,
    stopMagnetometerUpdates: @escaping (AnyHashable) -> Effect<Never, Never>
  ) {
    self._accelerometerData = accelerometerData
    self._attitudeReferenceFrame = attitudeReferenceFrame
    self._availableAttitudeReferenceFrames = availableAttitudeReferenceFrames
    self._deviceMotion = deviceMotion
    self._gyroData = gyroData
    self._isAccelerometerActive = isAccelerometerActive
    self._isAccelerometerAvailable = isAccelerometerAvailable
    self._isDeviceMotionActive = isDeviceMotionActive
    self._isDeviceMotionAvailable = isDeviceMotionAvailable
    self._isGyroActive = isGyroActive
    self._isGyroAvailable = isGyroAvailable
    self._isMagnetometerActive = isMagnetometerActive
    self._isMagnetometerAvailable = isMagnetometerAvailable
    self._magnetometerData = magnetometerData
    self._set = set
    self._startAccelerometerUpdates = startAccelerometerUpdates
    self._startDeviceMotionUpdates = startDeviceMotionUpdates
    self._startGyroUpdates = startGyroUpdates
    self._startMagnetometerUpdates = startMagnetometerUpdates
    self._stopAccelerometerUpdates = stopAccelerometerUpdates
    self._stopDeviceMotionUpdates = stopDeviceMotionUpdates
    self._stopGyroUpdates = stopGyroUpdates
    self._stopMagnetometerUpdates = stopMagnetometerUpdates
  }

  public struct Properties {
    public var accelerometerUpdateInterval: TimeInterval?
    public var deviceMotionUpdateInterval: TimeInterval?
    public var gyroUpdateInterval: TimeInterval?
    public var magnetometerUpdateInterval: TimeInterval?
    public var showsDeviceMovementDisplay: Bool?

    public init(
      accelerometerUpdateInterval: TimeInterval? = nil,
      deviceMotionUpdateInterval: TimeInterval? = nil,
      gyroUpdateInterval: TimeInterval? = nil,
      magnetometerUpdateInterval: TimeInterval? = nil,
      showsDeviceMovementDisplay: Bool? = nil
    ) {
      self.accelerometerUpdateInterval = accelerometerUpdateInterval
      self.deviceMotionUpdateInterval = deviceMotionUpdateInterval
      self.gyroUpdateInterval = gyroUpdateInterval
      self.magnetometerUpdateInterval = magnetometerUpdateInterval
      self.showsDeviceMovementDisplay = showsDeviceMovementDisplay
    }
  }

  var _accelerometerData: (AnyHashable) -> AccelerometerData?
  var _attitudeReferenceFrame: (AnyHashable) -> CMAttitudeReferenceFrame
  var _availableAttitudeReferenceFrames: () -> CMAttitudeReferenceFrame
  var _deviceMotion: (AnyHashable) -> DeviceMotion?
  var _gyroData: (AnyHashable) -> GyroData?
  var _isAccelerometerActive: (AnyHashable) -> Bool
  var _isAccelerometerAvailable: (AnyHashable) -> Bool
  var _isDeviceMotionActive: (AnyHashable) -> Bool
  var _isDeviceMotionAvailable: (AnyHashable) -> Bool
  var _isGyroActive: (AnyHashable) -> Bool
  var _isGyroAvailable: (AnyHashable) -> Bool
  var _isMagnetometerActive: (AnyHashable) -> Bool
  var _isMagnetometerAvailable: (AnyHashable) -> Bool
  var _magnetometerData: (AnyHashable) -> MagnetometerData?
  var _set: (AnyHashable, Properties) -> Effect<Never, Never>
  var _startAccelerometerUpdates: (AnyHashable, OperationQueue) -> Effect<AccelerometerData, Error>
  var _startDeviceMotionUpdates:
    (AnyHashable, CMAttitudeReferenceFrame, OperationQueue) -> Effect<DeviceMotion, Error>
  var _startGyroUpdates: (AnyHashable, OperationQueue) -> Effect<GyroData, Error>
  var _startMagnetometerUpdates: (AnyHashable, OperationQueue) -> Effect<MagnetometerData, Error>
  var _stopAccelerometerUpdates: (AnyHashable) -> Effect<Never, Never>
  var _stopDeviceMotionUpdates: (AnyHashable) -> Effect<Never, Never>
  var _stopGyroUpdates: (AnyHashable) -> Effect<Never, Never>
  var _stopMagnetometerUpdates: (AnyHashable) -> Effect<Never, Never>
}
