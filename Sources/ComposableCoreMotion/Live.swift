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

        accelerometerUpdatesSubscribers[id]?.send(completion: .finished)
        accelerometerUpdatesSubscribers[id] = subscriber
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

        deviceMotionUpdatesSubscribers[id]?.send(completion: .finished)
        deviceMotionUpdatesSubscribers[id] = subscriber
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

        deviceGyroUpdatesSubscribers[id]?.send(completion: .finished)
        deviceGyroUpdatesSubscribers[id] = subscriber
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

        deviceMagnetometerUpdatesSubscribers[id]?.send(completion: .finished)
        deviceMagnetometerUpdatesSubscribers[id] = subscriber
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
        accelerometerUpdatesSubscribers[id]?.send(completion: .finished)
      }
    },
    stopDeviceMotionUpdates: { id in
      .fireAndForget {
        guard let manager = managers[id] else { return }
        manager.stopDeviceMotionUpdates()
        deviceMotionUpdatesSubscribers[id]?.send(completion: .finished)
      }
    },
    stopGyroUpdates: { id in
      .fireAndForget {
        guard let manager = managers[id] else { return }
        manager.stopGyroUpdates()
        deviceGyroUpdatesSubscribers[id]?.send(completion: .finished)
      }
    },
    stopMagnetometerUpdates: { id in
      .fireAndForget {
        guard let manager = managers[id] else { return }
        manager.stopMagnetometerUpdates()
        deviceMagnetometerUpdatesSubscribers[id]?.send(completion: .finished)
      }
    })
}

private var accelerometerUpdatesSubscribers:
  [AnyHashable: Effect<AccelerometerData, MotionManager.Error>.Subscriber] = [:]
private var deviceMotionUpdatesSubscribers:
  [AnyHashable: Effect<DeviceMotion, MotionManager.Error>.Subscriber] = [:]
private var deviceGyroUpdatesSubscribers:
  [AnyHashable: Effect<GyroData, MotionManager.Error>.Subscriber] = [:]
private var deviceMagnetometerUpdatesSubscribers:
  [AnyHashable: Effect<MagnetometerData, MotionManager.Error>.Subscriber] = [:]
private var managers: [AnyHashable: CMMotionManager] = [:]
