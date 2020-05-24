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

  public func set(properties: Properties) -> Effect<Never, Never> {
    self.set(properties)
  }

  public func startDeviceMotionUpdates(
    using referenceFrame: CMAttitudeReferenceFrame,
    to queue: OperationQueue
    ) -> Effect<DeviceMotion, Error> {
    self.startDeviceMotionUpdates(referenceFrame, queue)
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
    self.accelerometerData = accelerometerData
    self.attitudeReferenceFrame = attitudeReferenceFrame
    self.availableAttitudeReferenceFrames = availableAttitudeReferenceFrames
    self.deviceMotion = deviceMotion
    self.gyroData = gyroData
    self.isAccelerometerActive = isAccelerometerActive
    self.isAccelerometerAvailable = isAccelerometerAvailable
    self.isDeviceMotionActive = isDeviceMotionActive
    self.isDeviceMotionAvailable = isDeviceMotionAvailable
    self.isGyroActive = isGyroActive
    self.isGyroAvailable = isGyroAvailable
    self.isMagnetometerActive = isMagnetometerActive
    self.isMagnetometerAvailable = isMagnetometerAvailable
    self.magnetometerData = magnetometerData
    self.set = set
    self.startAccelerometerUpdates = startAccelerometerUpdates
    self.startDeviceMotionUpdates = startDeviceMotionUpdates
    self.startGyroUpdates = startGyroUpdates
    self.startMagnetometerUpdates = startMagnetometerUpdates
    self.stopAccelerometerUpdates = stopAccelerometerUpdates
    self.stopDeviceMotionUpdates = stopDeviceMotionUpdates
    self.stopGyroUpdates = stopGyroUpdates
    self.stopMagnetometerUpdates = stopMagnetometerUpdates
  }

  public var accelerometerData: () -> AccelerometerData?
  public var attitudeReferenceFrame: () -> CMAttitudeReferenceFrame
  public var availableAttitudeReferenceFrames: () -> CMAttitudeReferenceFrame
  public var deviceMotion: () -> DeviceMotion?
  public var gyroData: () -> GyroData?
  public var isAccelerometerActive: () -> Bool
  public var isAccelerometerAvailable: () -> Bool
  public var isDeviceMotionActive: () -> Bool
  public var isDeviceMotionAvailable: () -> Bool
  public var isGyroActive: () -> Bool
  public var isGyroAvailable: () -> Bool
  public var isMagnetometerActive: () -> Bool
  public var isMagnetometerAvailable: () -> Bool
  public var magnetometerData: () -> MagnetometerData?
  var set: (Properties) -> Effect<Never, Never>
  var startAccelerometerUpdates: (OperationQueue) -> Effect<AccelerometerData, Error>
  var startDeviceMotionUpdates:
    (CMAttitudeReferenceFrame, OperationQueue) -> Effect<DeviceMotion, Error>
  var startGyroUpdates: (OperationQueue) -> Effect<GyroData, Error>
  var startMagnetometerUpdates: (OperationQueue) -> Effect<MagnetometerData, Error>
  public var stopAccelerometerUpdates: () -> Effect<Never, Never>
  public var stopDeviceMotionUpdates: () -> Effect<Never, Never>
  public var stopGyroUpdates: () -> Effect<Never, Never>
  public var stopMagnetometerUpdates: () -> Effect<Never, Never>

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
}
