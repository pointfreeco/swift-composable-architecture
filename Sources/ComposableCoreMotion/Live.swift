import Combine
import ComposableArchitecture
import CoreMotion

extension MotionManager {
  public static let live = MotionManager(
    accelerometerData: { manager.accelerometerData.map(AccelerometerData.init) },
    attitudeReferenceFrame: { manager.attitudeReferenceFrame },
    availableAttitudeReferenceFrames: { CMMotionManager.availableAttitudeReferenceFrames() },
    deviceMotion: { manager.deviceMotion.map(DeviceMotion.init) },
    gyroData: { manager.gyroData.map(GyroData.init) },
    isAccelerometerActive: { manager.isAccelerometerActive },
    isAccelerometerAvailable: { manager.isAccelerometerAvailable },
    isDeviceMotionActive: { manager.isDeviceMotionActive },
    isDeviceMotionAvailable: { manager.isDeviceMotionAvailable },
    isGyroActive: { manager.isGyroActive },
    isGyroAvailable: { manager.isGyroAvailable },
    isMagnetometerActive: { manager.isDeviceMotionActive },
    isMagnetometerAvailable: { manager.isMagnetometerAvailable },
    magnetometerData: { manager.magnetometerData.map(MagnetometerData.init) },
    set: { properties in
      .fireAndForget {
        if let accelerometerUpdateInterval = properties.accelerometerUpdateInterval {
          manager.accelerometerUpdateInterval = accelerometerUpdateInterval
        }
        if let deviceMotionUpdateInterval = properties.deviceMotionUpdateInterval {
          manager.deviceMotionUpdateInterval = deviceMotionUpdateInterval
        }
        if let gyroUpdateInterval = properties.gyroUpdateInterval {
          manager.gyroUpdateInterval = gyroUpdateInterval
        }
        if let magnetometerUpdateInterval = properties.magnetometerUpdateInterval {
          manager.magnetometerUpdateInterval = magnetometerUpdateInterval
        }
        if let showsDeviceMovementDisplay = properties.showsDeviceMovementDisplay {
          manager.showsDeviceMovementDisplay = showsDeviceMovementDisplay
        }
      }
  },
    startAccelerometerUpdates: { queue in
      Effect.run { subscriber in
        accelerometerUpdatesSubscriber?.send(completion: .finished)
        accelerometerUpdatesSubscriber = subscriber
        manager.startAccelerometerUpdates(to: queue) { data, error in
          if let data = data {
            subscriber.send(.init(data))
          } else if let error = error {
            subscriber.send(completion: .failure(.init(error)))
          }
        }
        return AnyCancellable {
          manager.stopAccelerometerUpdates()
        }
      }
  },
    startDeviceMotionUpdates: { frame, queue in
      Effect.run { subscriber in
        deviceMotionUpdatesSubscriber?.send(completion: .finished)
        deviceMotionUpdatesSubscriber = subscriber
        manager.startDeviceMotionUpdates(using: frame, to: queue) { data, error in
          if let data = data {
            subscriber.send(.init(data))
          } else if let error = error {
            subscriber.send(completion: .failure(.init(error)))
          }
        }
        return AnyCancellable {
          manager.stopDeviceMotionUpdates()
        }
      }
  },
    startGyroUpdates: { queue in
      Effect.run { subscriber in
        deviceGyroUpdatesSubscriber?.send(completion: .finished)
        deviceGyroUpdatesSubscriber = subscriber
        manager.startGyroUpdates(to: queue) { data, error in
          if let data = data {
            subscriber.send(.init(data))
          } else if let error = error {
            subscriber.send(completion: .failure(.init(error)))
          }
        }
        return AnyCancellable {
          manager.stopGyroUpdates()
        }
      }
  },
    startMagnetometerUpdates: { queue in
      Effect.run { subscriber in
        deviceMagnetometerUpdatesSubscriber?.send(completion: .finished)
        deviceMagnetometerUpdatesSubscriber = subscriber
        manager.startMagnetometerUpdates(to: queue) { data, error in
          if let data = data {
            subscriber.send(.init(data))
          } else if let error = error {
            subscriber.send(completion: .failure(.init(error)))
          }
        }
        return AnyCancellable {
          manager.stopMagnetometerUpdates()
        }
      }
  },
    stopAccelerometerUpdates: {
      .fireAndForget {
        manager.stopAccelerometerUpdates()
        accelerometerUpdatesSubscriber?.send(completion: .finished)
      }
  },
    stopDeviceMotionUpdates: {
      .fireAndForget {
        manager.stopDeviceMotionUpdates()
        deviceMotionUpdatesSubscriber?.send(completion: .finished)
      }
  },
    stopGyroUpdates: {
      .fireAndForget {
        manager.stopGyroUpdates()
        deviceGyroUpdatesSubscriber?.send(completion: .finished)
      }
  },
    stopMagnetometerUpdates: {
      .fireAndForget {
        manager.stopMagnetometerUpdates()
        deviceMagnetometerUpdatesSubscriber?.send(completion: .finished)
      }
  })
}

// TODO: store these by id?
private var accelerometerUpdatesSubscriber: Effect<AccelerometerData, MotionManager.Error>.Subscriber<AccelerometerData, MotionManager.Error>?
private var deviceMotionUpdatesSubscriber: Effect<DeviceMotion, MotionManager.Error>.Subscriber<DeviceMotion, MotionManager.Error>?
private var deviceGyroUpdatesSubscriber: Effect<GyroData, MotionManager.Error>.Subscriber<GyroData, MotionManager.Error>?
private var deviceMagnetometerUpdatesSubscriber: Effect<MagnetometerData, MotionManager.Error>.Subscriber<MagnetometerData, MotionManager.Error>?

private var manager: CMMotionManager {
  _manager = _manager ?? CMMotionManager()
  return _manager!
}
private var _manager: CMMotionManager?
