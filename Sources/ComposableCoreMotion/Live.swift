import Combine
import ComposableArchitecture
import CoreMotion

extension MotionManager {
  public static let live = MotionManager(
    accelerometerData: { id in managers[id]?.accelerometerData.map(AccelerometerData.init) },
    attitudeReferenceFrame: { id in managers[id]?.attitudeReferenceFrame ?? .init() },
    availableAttitudeReferenceFrames: { CMMotionManager.availableAttitudeReferenceFrames() },
    deviceMotion: { id in managers[id]?.deviceMotion.map(DeviceMotion.init) },
    gyroData: { id in managers[id]?.gyroData.map(GyroData.init) },
    isAccelerometerActive: { id in managers[id]?.isAccelerometerActive ?? false },
    isAccelerometerAvailable: { id in managers[id]?.isAccelerometerAvailable ?? false },
    isDeviceMotionActive: { id in managers[id]?.isDeviceMotionActive ?? false },
    isDeviceMotionAvailable: { id in managers[id]?.isDeviceMotionAvailable ?? false },
    isGyroActive: { id in managers[id]?.isGyroActive ?? false },
    isGyroAvailable: { id in managers[id]?.isGyroAvailable ?? false },
    isMagnetometerActive: { id in managers[id]?.isDeviceMotionActive ?? false },
    isMagnetometerAvailable: { id in managers[id]?.isMagnetometerAvailable ?? false },
    magnetometerData: { id in managers[id]?.magnetometerData.map(MagnetometerData.init) },
    set: { id, properties in
      .fireAndForget {
        guard let manager = managers[id] else { return }

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
    startAccelerometerUpdates: { id, queue in
      return Effect.run { subscriber in
        guard let manager = managers[id] else { return AnyCancellable {} }

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
    startDeviceMotionUpdates: { id, frame, queue in
      return Effect.run { subscriber in
        guard let manager = managers[id] else { return AnyCancellable {} }

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
    startGyroUpdates: { id, queue in
      return Effect.run { subscriber in
        guard let manager = managers[id] else { return AnyCancellable {} }

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
    startMagnetometerUpdates: { id, queue in
      return Effect.run { subscriber in
        guard let manager = managers[id] else { return AnyCancellable {} }

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
    stopAccelerometerUpdates: { id in
      .fireAndForget {
        guard let manager = managers[id] else { return }
        manager.stopAccelerometerUpdates()
        accelerometerUpdatesSubscriber?.send(completion: .finished)
      }
  },
    stopDeviceMotionUpdates: { id in
      .fireAndForget {
        guard let manager = managers[id] else { return }
        manager.stopDeviceMotionUpdates()
        deviceMotionUpdatesSubscriber?.send(completion: .finished)
      }
  },
    stopGyroUpdates: { id in
      .fireAndForget {
        guard let manager = managers[id] else { return }
        manager.stopGyroUpdates()
        deviceGyroUpdatesSubscriber?.send(completion: .finished)
      }
  },
    stopMagnetometerUpdates: { id in
      .fireAndForget {
        guard let manager = managers[id] else { return }
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

var managers: [AnyHashable: CMMotionManager] = [:]
