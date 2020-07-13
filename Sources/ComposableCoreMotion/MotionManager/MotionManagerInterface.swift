#if canImport(CoreMotion)
  import ComposableArchitecture
  import CoreMotion

  /// A wrapper around Core Motion's `CMMotionManager` that exposes its functionality through effects
  /// and actions, making it easy to use with the Composable Architecture, and easy to test.
  ///
  /// To use in your application, you can add an action to your feature's domain that represents the
  /// type of motion data you are interested in receiving. For example, if you only want motion
  /// updates, then you can add the following action:
  ///
  ///     import ComposableCoreLocation
  ///
  ///     enum FeatureAction {
  ///       case motionUpdate(Result<DeviceMotion, NSError>)
  ///
  ///       // Your feature's other actions:
  ///       ...
  ///     }
  ///
  /// This action will be sent every time the motion manager receives new device motion data.
  ///
  /// Next, add a `MotionManager` type, which is a wrapper around a `CMMotionManager` that this
  /// library provides, to your feature's environment of dependencies:
  ///
  ///     struct FeatureEnvironment {
  ///       var motionManager: MotionManager
  ///
  ///       // Your feature's other dependencies:
  ///       ...
  ///     }
  ///
  /// Then, create a motion manager by returning an effect from our reducer. You can either do this
  /// when your feature starts up, such as when `onAppear` is invoked, or you can do it when a user
  /// action occurs, such as when the user taps a button.
  ///
  /// As an example, say we want to create a motion manager and start listening for motion updates
  /// when a "Record" button is tapped. Then we can can do both of those things by executing two
  /// effects, one after the other:
  ///
  ///     let featureReducer = Reducer<FeatureState, FeatureAction, FeatureEnvironment> {
  ///       state, action, environment in
  ///
  ///       // A unique identifier for our location manager, just in case we want to use
  ///       // more than one in our application.
  ///       struct MotionManagerId: Hashable {}
  ///
  ///       switch action {
  ///       case .recordingButtonTapped:
  ///         return .concatenate(
  ///           environment.motionManager
  ///             .create(id: MotionManagerId())
  ///             .fireAndForget(),
  ///
  ///           environment.motionManager
  ///             .startDeviceMotionUpdates(id: MotionManagerId(), using: .xArbitraryZVertical, to: .main)
  ///             .mapError { $0 as NSError }
  ///             .catchToEffect()
  ///             .map(AppAction.motionUpdate)
  ///         )
  ///
  ///       ...
  ///       }
  ///     }
  ///
  /// After those effects are executed you will get a steady stream of device motion updates sent to
  /// the `.motionUpdate` action, which you can handle in the reducer. For example, to compute how
  /// much the device is moving up and down we can take the dot product of the device's gravity vector
  /// with the device's acceleration vector, and we could store that in the feature's state:
  ///
  ///     case let .motionUpdate(.success(deviceMotion)):
  ///        state.zs.append(
  ///          motion.gravity.x * motion.userAcceleration.x
  ///            + motion.gravity.y * motion.userAcceleration.y
  ///            + motion.gravity.z * motion.userAcceleration.z
  ///        )
  ///
  ///     case let .motionUpdate(.failure(error)):
  ///       // Do something with the motion update failure, like show an alert.
  ///
  /// And then later, if you want to stop receiving motion updates, such as when a "Stop" button is
  /// tapped, we can execute an effect to stop the motion manager, and even fully destroy it if we
  /// don't need the manager anymore:
  ///
  ///     case .stopButtonTapped:
  ///       return .concatenate(
  ///         environment.motionManager
  ///           .stopDeviceMotionUpdates(id: MotionManagerId())
  ///           .fireAndForget(),
  ///
  ///         environment.motionManager
  ///           .destroy(id: MotionManagerId())
  ///           .fireAndForget()
  ///       )
  ///
  /// That is enough to implement a basic application that interacts with Core Motion.
  ///
  /// But the true power of building your application and interfacing with Core Motion this way is the
  /// ability to instantly _test_ how your application behaves with Core Motion. We start by creating
  /// a `TestStore` whose environment contains a `.mock` version of the `MotionManager`. The `.mock`
  /// function allows you to create a fully controlled version of the motion manager that does not
  /// deal with a real `CMMotionManager` at all. Instead, you override whichever endpoints your
  /// feature needs to supply deterministic functionality.
  ///
  /// For example, let's test that we property start the motion manager when we tap the record button,
  /// and that we compute the z-motion correctly, and further that we stop the motion manager when we
  /// tap the stop button. We can construct a `TestStore` with a mock motion manager that keeps track
  /// of when the manager is created and destroyed, and further we can even substitute in a subject
  /// that we control for device motion updates. This allows us to send any data we want to for the
  /// device motion.
  ///
  ///     func testFeature() {
  ///       let motionSubject = PassthroughSubject<DeviceMotion, Error>()
  ///       var motionManagerIsLive = false
  ///
  ///       let store = TestStore(
  ///         initialState: .init(),
  ///         reducer: appReducer,
  ///         environment: .init(
  ///           motionManager: .mock(
  ///             create: { _ in .fireAndForget { motionManagerIsLive = true } },
  ///             destroy: { _ in .fireAndForget { motionManagerIsLive = false } },
  ///             startDeviceMotionUpdates: { _, _, _ in motionSubject.eraseToEffect() },
  ///             stopDeviceMotionUpdates: { _ in
  ///               .fireAndForget { motionSubject.send(completion: .finished) }
  ///             }
  ///           )
  ///         )
  ///       )
  ///     }
  ///
  /// We can then make an assertion on our store that plays a basic user script. We can simulate the
  /// situation in which a user taps the record button, then some device motion data is received, and
  /// finally the user taps the stop button. During that script of user actions we expect the motion
  /// manager to be started, then for some z-motion values to be accumulated, and finally for the
  /// motion manager to be stopped:
  ///
  ///     let deviceMotion = DeviceMotion(
  ///       attitude: .init(quaternion: .init(x: 1, y: 0, z: 0, w: 0)),
  ///       gravity: CMAcceleration(x: 1, y: 2, z: 3),
  ///       heading: 0,
  ///       magneticField: .init(field: .init(x: 0, y: 0, z: 0), accuracy: .high),
  ///       rotationRate: .init(x: 0, y: 0, z: 0),
  ///       timestamp: 0,
  ///       userAcceleration: CMAcceleration(x: 4, y: 5, z: 6)
  ///     )
  ///
  ///     store.assert(
  ///       .send(.recordingButtonTapped) {
  ///         XCTAssertEqual(motionManagerIsLive, true)
  ///       },
  ///       .do { motionSubject.send(deviceMotion) },
  ///       .receive(.motionUpdate(.success(deviceMotion))) {
  ///         $0.zs = [32]
  ///       },
  ///       .send(.stopButtonTapped) {
  ///         XCTAssertEqual(motionManagerIsLive, false)
  ///       }
  ///     )
  ///
  /// This is only the tip of the iceberg. We can access any part of the `CMMotionManager` API in this
  /// way, and instantly unlock testability with how the motion functionality integrates with our core
  /// application logic. This can be incredibly powerful, and is typically not the kind of thing one
  /// can test easily.
  ///
  @available(iOS 4.0, *)
  @available(macCatalyst 13.0, *)
  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS 2.0, *)
  public struct MotionManager {
    /// The latest sample of accelerometer data.
    public func accelerometerData(id: AnyHashable) -> AccelerometerData? {
      self.accelerometerData(id)
    }

    /// Returns either the reference frame currently being used or the default attitude reference
    /// frame.
    public func attitudeReferenceFrame(id: AnyHashable) -> CMAttitudeReferenceFrame {
      self.attitudeReferenceFrame(id)
    }

    /// Creates a motion manager.
    ///
    /// A motion manager must be first created before you can use its functionality, such as starting
    /// device motion updates or accessing data directly from the manager.
    public func create(id: AnyHashable) -> Effect<Never, Never> {
      self.create(id)
    }

    /// Destroys a currently running motion manager.
    ///
    /// In is good practice to destroy a motion manager once you are done with it, such as when you
    /// leave a screen or no longer need motion data.
    public func destroy(id: AnyHashable) -> Effect<Never, Never> {
      self.destroy(id)
    }

    /// The latest sample of device-motion data.
    public func deviceMotion(id: AnyHashable) -> DeviceMotion? {
      self.deviceMotion(id)
    }

    /// The latest sample of gyroscope data.
    public func gyroData(id: AnyHashable) -> GyroData? {
      self.gyroData(id)
    }

    /// A Boolean value that indicates whether accelerometer updates are currently happening.
    public func isAccelerometerActive(id: AnyHashable) -> Bool {
      self.isAccelerometerActive(id)
    }

    /// A Boolean value that indicates whether an accelerometer is available on the device.
    public func isAccelerometerAvailable(id: AnyHashable) -> Bool {
      self.isAccelerometerAvailable(id)
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

    /// A Boolean value that determines whether gyroscope updates are currently happening.
    public func isGyroActive(id: AnyHashable) -> Bool {
      self.isGyroActive(id)
    }

    /// A Boolean value that indicates whether a gyroscope is available on the device.
    public func isGyroAvailable(id: AnyHashable) -> Bool {
      self.isGyroAvailable(id)
    }

    /// A Boolean value that determines whether magnetometer updates are currently happening.
    public func isMagnetometerActive(id: AnyHashable) -> Bool {
      self.isMagnetometerActive(id)
    }

    /// A Boolean value that indicates whether a magnetometer is available on the device.
    public func isMagnetometerAvailable(id: AnyHashable) -> Bool {
      self.isMagnetometerAvailable(id)
    }

    /// The latest sample of magnetometer data.
    public func magnetometerData(id: AnyHashable) -> MagnetometerData? {
      self.magnetometerData(id)
    }

    /// Sets certain properties on the motion manager.
    public func set(
      id: AnyHashable,
      accelerometerUpdateInterval: TimeInterval? = nil,
      deviceMotionUpdateInterval: TimeInterval? = nil,
      gyroUpdateInterval: TimeInterval? = nil,
      magnetometerUpdateInterval: TimeInterval? = nil,
      showsDeviceMovementDisplay: Bool? = nil
    ) -> Effect<Never, Never> {
      self.set(
        id,
        .init(
          accelerometerUpdateInterval: accelerometerUpdateInterval,
          deviceMotionUpdateInterval: deviceMotionUpdateInterval,
          gyroUpdateInterval: gyroUpdateInterval,
          magnetometerUpdateInterval: magnetometerUpdateInterval,
          showsDeviceMovementDisplay: showsDeviceMovementDisplay
        )
      )
    }

    /// Starts accelerometer updates without a handler.
    ///
    /// Returns a long-living effect that emits accelerometer data each time the motion manager
    /// receives a new value.
    public func startAccelerometerUpdates(
      id: AnyHashable,
      to queue: OperationQueue = .main
    ) -> Effect<AccelerometerData, Error> {
      self.startAccelerometerUpdates(id, queue)
    }

    /// Starts device-motion updates without a block handler.
    ///
    /// Returns a long-living effect that emits device motion data each time the motion manager
    /// receives a new value.
    public func startDeviceMotionUpdates(
      id: AnyHashable,
      using referenceFrame: CMAttitudeReferenceFrame,
      to queue: OperationQueue = .main
    ) -> Effect<DeviceMotion, Error> {
      self.startDeviceMotionUpdates(id, referenceFrame, queue)
    }

    /// Starts gyroscope updates without a handler.
    ///
    /// Returns a long-living effect that emits gyro data each time the motion manager receives a new
    /// value.
    public func startGyroUpdates(
      id: AnyHashable,
      to queue: OperationQueue = .main
    ) -> Effect<GyroData, Error> {
      self.startGyroUpdates(id, queue)
    }

    /// Starts magnetometer updates without a block handler.
    ///
    /// Returns a long-living effect that emits magnetometer data each time the motion manager
    /// receives a new value.
    public func startMagnetometerUpdates(
      id: AnyHashable,
      to queue: OperationQueue = .main
    ) -> Effect<MagnetometerData, Error> {
      self.startMagnetometerUpdates(id, queue)
    }

    /// Stops accelerometer updates.
    public func stopAccelerometerUpdates(id: AnyHashable) -> Effect<Never, Never> {
      self.stopAccelerometerUpdates(id)
    }

    /// Stops device-motion updates.
    public func stopDeviceMotionUpdates(id: AnyHashable) -> Effect<Never, Never> {
      self.stopDeviceMotionUpdates(id)
    }

    /// Stops gyroscope updates.
    public func stopGyroUpdates(id: AnyHashable) -> Effect<Never, Never> {
      self.stopGyroUpdates(id)
    }

    /// Stops magnetometer updates.
    public func stopMagnetometerUpdates(id: AnyHashable) -> Effect<Never, Never> {
      self.stopMagnetometerUpdates(id)
    }

    public init(
      accelerometerData: @escaping (AnyHashable) -> AccelerometerData?,
      attitudeReferenceFrame: @escaping (AnyHashable) -> CMAttitudeReferenceFrame,
      availableAttitudeReferenceFrames: @escaping () -> CMAttitudeReferenceFrame,
      create: @escaping (AnyHashable) -> Effect<Never, Never>,
      destroy: @escaping (AnyHashable) -> Effect<Never, Never>,
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
      set: @escaping (AnyHashable, Properties) -> Effect<Never, Never>,
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
      self.accelerometerData = accelerometerData
      self.attitudeReferenceFrame = attitudeReferenceFrame
      self.availableAttitudeReferenceFrames = availableAttitudeReferenceFrames
      self.create = create
      self.destroy = destroy
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

    var accelerometerData: (AnyHashable) -> AccelerometerData?
    var attitudeReferenceFrame: (AnyHashable) -> CMAttitudeReferenceFrame
    /// Returns a bitmask specifying the available attitude reference frames on the device.
    var availableAttitudeReferenceFrames: () -> CMAttitudeReferenceFrame
    var create: (AnyHashable) -> Effect<Never, Never>
    var destroy: (AnyHashable) -> Effect<Never, Never>
    var deviceMotion: (AnyHashable) -> DeviceMotion?
    var gyroData: (AnyHashable) -> GyroData?
    var isAccelerometerActive: (AnyHashable) -> Bool
    var isAccelerometerAvailable: (AnyHashable) -> Bool
    var isDeviceMotionActive: (AnyHashable) -> Bool
    var isDeviceMotionAvailable: (AnyHashable) -> Bool
    var isGyroActive: (AnyHashable) -> Bool
    var isGyroAvailable: (AnyHashable) -> Bool
    var isMagnetometerActive: (AnyHashable) -> Bool
    var isMagnetometerAvailable: (AnyHashable) -> Bool
    var magnetometerData: (AnyHashable) -> MagnetometerData?
    var set: (AnyHashable, Properties) -> Effect<Never, Never>
    var startAccelerometerUpdates: (AnyHashable, OperationQueue) -> Effect<AccelerometerData, Error>
    var startDeviceMotionUpdates:
      (AnyHashable, CMAttitudeReferenceFrame, OperationQueue) -> Effect<DeviceMotion, Error>
    var startGyroUpdates: (AnyHashable, OperationQueue) -> Effect<GyroData, Error>
    var startMagnetometerUpdates: (AnyHashable, OperationQueue) -> Effect<MagnetometerData, Error>
    var stopAccelerometerUpdates: (AnyHashable) -> Effect<Never, Never>
    var stopDeviceMotionUpdates: (AnyHashable) -> Effect<Never, Never>
    var stopGyroUpdates: (AnyHashable) -> Effect<Never, Never>
    var stopMagnetometerUpdates: (AnyHashable) -> Effect<Never, Never>
  }
#endif
