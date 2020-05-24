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

  public var accelerometerData: AccelerometerData? {
    self._accelerometerData()
  }

  public var attitudeReferenceFrame: CMAttitudeReferenceFrame {
    self._attitudeReferenceFrame()
  }

  public var availableAttitudeReferenceFrames: CMAttitudeReferenceFrame {
    self._availableAttitudeReferenceFrames()
  }

  public var deviceMotion: DeviceMotion? {
    self._deviceMotion()
  }

  public var gyroData: GyroData? {
    self._gyroData()
  }

  public var isAccelerometerActive: Bool {
    self._isAccelerometerActive()
  }

  public var isAccelerometerAvailable: Bool {
    self._isAccelerometerAvailable()
  }

  public var isDeviceMotionActive: Bool {
    self._isDeviceMotionActive()
  }

  public var isDeviceMotionAvailable: Bool {
    self._isDeviceMotionAvailable()
  }

  public var isGyroActive: Bool {
    self._isGyroActive()
  }

  public var isGyroAvailable: Bool {
    self._isGyroAvailable()
  }

  public var isMagnetometerActive: Bool {
    self._isMagnetometerActive()
  }

  public var isMagnetometerAvailable: Bool {
    self._isMagnetometerAvailable()
  }

  public var magnetometerData: MagnetometerData? {
    self._magnetometerData()
  }

  public func set(properties: Properties) -> Effect<Never, Never> {
    self._set(properties)
  }

  public func startAccelerometerUpdates(
    to queue: OperationQueue
  ) -> Effect<AccelerometerData, Error> {
    self._startAccelerometerUpdates(queue)
  }

  public func startDeviceMotionUpdates(
    using referenceFrame: CMAttitudeReferenceFrame,
    to queue: OperationQueue
    ) -> Effect<DeviceMotion, Error> {
    self._startDeviceMotionUpdates(referenceFrame, queue)
  }

  public func startGyroUpdates(to queue: OperationQueue) -> Effect<GyroData, Error> {
    self._startGyroUpdates(queue)
  }

  public func startMagnetometerUpdates(to queue: OperationQueue) -> Effect<MagnetometerData, Error> {
    self._startMagnetometerUpdates(queue)
  }

  public func stopAccelerometerUpdates() -> Effect<Never, Never> {
    self._stopAccelerometerUpdates()
  }

  public func stopDeviceMotionUpdates() -> Effect<Never, Never> {
    self._stopDeviceMotionUpdates()
  }

  public func stopGyroUpdates() -> Effect<Never, Never> {
    self._stopGyroUpdates()
  }

  public func stopMagnetometerUpdates() -> Effect<Never, Never> {
    self._stopMagnetometerUpdates()
  }

  public init(
    accelerometerData: @escaping () -> AccelerometerData?,
    attitudeReferenceFrame: @escaping () -> CMAttitudeReferenceFrame,
    availableAttitudeReferenceFrames: @escaping () -> CMAttitudeReferenceFrame,
    deviceMotion: @escaping () -> DeviceMotion?,
    gyroData: @escaping () -> GyroData?,
    isAccelerometerActive: @escaping () -> Bool,
    isAccelerometerAvailable: @escaping () -> Bool,
    isDeviceMotionActive: @escaping () -> Bool,
    isDeviceMotionAvailable: @escaping () -> Bool,
    isGyroActive: @escaping () -> Bool,
    isGyroAvailable: @escaping () -> Bool,
    isMagnetometerActive: @escaping () -> Bool,
    isMagnetometerAvailable: @escaping () -> Bool,
    magnetometerData: @escaping () -> MagnetometerData?,
    set: @escaping (MotionManager.Properties) -> Effect<Never, Never>,
    startAccelerometerUpdates: @escaping (OperationQueue) -> Effect<AccelerometerData, Error>,
    startDeviceMotionUpdates: @escaping (CMAttitudeReferenceFrame, OperationQueue) -> Effect<DeviceMotion, Error>,
    startGyroUpdates: @escaping (OperationQueue) -> Effect<GyroData, Error>,
    startMagnetometerUpdates: @escaping (OperationQueue) -> Effect<MagnetometerData, Error>,
    stopAccelerometerUpdates: @escaping () -> Effect<Never, Never>,
    stopDeviceMotionUpdates: @escaping () -> Effect<Never, Never>,
    stopGyroUpdates: @escaping () -> Effect<Never, Never>,
    stopMagnetometerUpdates: @escaping () -> Effect<Never, Never>
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

  var _accelerometerData: () -> AccelerometerData?
  var _attitudeReferenceFrame: () -> CMAttitudeReferenceFrame
  var _availableAttitudeReferenceFrames: () -> CMAttitudeReferenceFrame
  var _deviceMotion: () -> DeviceMotion?
  var _gyroData: () -> GyroData?
  var _isAccelerometerActive: () -> Bool
  var _isAccelerometerAvailable: () -> Bool
  var _isDeviceMotionActive: () -> Bool
  var _isDeviceMotionAvailable: () -> Bool
  var _isGyroActive: () -> Bool
  var _isGyroAvailable: () -> Bool
  var _isMagnetometerActive: () -> Bool
  var _isMagnetometerAvailable: () -> Bool
  var _magnetometerData: () -> MagnetometerData?
  var _set: (Properties) -> Effect<Never, Never>
  var _startAccelerometerUpdates: (OperationQueue) -> Effect<AccelerometerData, Error>
  var _startDeviceMotionUpdates:
    (CMAttitudeReferenceFrame, OperationQueue) -> Effect<DeviceMotion, Error>
  var _startGyroUpdates: (OperationQueue) -> Effect<GyroData, Error>
  var _startMagnetometerUpdates: (OperationQueue) -> Effect<MagnetometerData, Error>
  var _stopAccelerometerUpdates: () -> Effect<Never, Never>
  var _stopDeviceMotionUpdates: () -> Effect<Never, Never>
  var _stopGyroUpdates: () -> Effect<Never, Never>
  var _stopMagnetometerUpdates: () -> Effect<Never, Never>
}
