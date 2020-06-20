import Combine
import ComposableArchitecture
import CoreMotion

extension MotionManager {
  public static let live = MotionManager(
    accelerometerData: { id in
      requireMotionManager(id: id)?.accelerometerData.map(AccelerometerData.init)
  },
    attitudeReferenceFrame: { id in
      requireMotionManager(id: id)?.attitudeReferenceFrame ?? .init()
  },
    availableAttitudeReferenceFrames: {
      CMMotionManager.availableAttitudeReferenceFrames()
  },
    deviceMotion: { id in
      requireMotionManager(id: id)?.deviceMotion.map(DeviceMotion.init)
  },
    gyroData: { id in
      requireMotionManager(id: id)?.gyroData.map(GyroData.init)
  },
    isAccelerometerActive: { id in
      requireMotionManager(id: id)?.isAccelerometerActive ?? false
  },
    isAccelerometerAvailable: { id in
      requireMotionManager(id: id)?.isAccelerometerAvailable ?? false
  },
    isDeviceMotionActive: { id in
      requireMotionManager(id: id)?.isDeviceMotionActive ?? false
  },
    isDeviceMotionAvailable: { id in
      requireMotionManager(id: id)?.isDeviceMotionAvailable ?? false
  },
    isGyroActive: { id in
      requireMotionManager(id: id)?.isGyroActive ?? false
  },
    isGyroAvailable: { id in
      requireMotionManager(id: id)?.isGyroAvailable ?? false
  },
    isMagnetometerActive: { id in
      requireMotionManager(id: id)?.isDeviceMotionActive ?? false
  },
    isMagnetometerAvailable: { id in
      requireMotionManager(id: id)?.isMagnetometerAvailable ?? false
  },
    magnetometerData: { id in
      requireMotionManager(id: id)?.magnetometerData.map(MagnetometerData.init)
  },
    set: { id, properties in
      .fireAndForget {
        guard let manager = managers[id]
          else { couldNotFindMotionManager(id: id); return }

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
        guard let manager = managers[id]
          else { couldNotFindMotionManager(id: id); return AnyCancellable { } }

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
        guard let manager = managers[id]
          else { couldNotFindMotionManager(id: id); return AnyCancellable { } }

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
        guard let manager = managers[id]
          else { couldNotFindMotionManager(id: id); return AnyCancellable { } }

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
        guard let manager = managers[id]
          else { couldNotFindMotionManager(id: id); return AnyCancellable { } }

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
        guard let manager = managers[id]
          else { couldNotFindMotionManager(id: id); return }
        manager.stopAccelerometerUpdates()
        accelerometerUpdatesSubscribers[id]?.send(completion: .finished)
      }
    },
    stopDeviceMotionUpdates: { id in
      .fireAndForget {
        guard let manager = managers[id]
          else { couldNotFindMotionManager(id: id); return }
        manager.stopDeviceMotionUpdates()
        deviceMotionUpdatesSubscribers[id]?.send(completion: .finished)
      }
    },
    stopGyroUpdates: { id in
      .fireAndForget {
        guard let manager = managers[id]
          else { couldNotFindMotionManager(id: id); return }
        manager.stopGyroUpdates()
        deviceGyroUpdatesSubscribers[id]?.send(completion: .finished)
      }
    },
    stopMagnetometerUpdates: { id in
      .fireAndForget {
        guard let manager = managers[id]
          else { couldNotFindMotionManager(id: id); return }
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

private func requireMotionManager(id: AnyHashable) -> CMMotionManager? {
  if managers[id] == nil {
    couldNotFindMotionManager(id: id)
  }
  return managers[id]
}

private func couldNotFindMotionManager(id: Any) {
  assertionFailure("""
    A motion manager could not be found with the id \(id). This is considered a programmer error.
    You should not invoke methods on a motion manager before it has been created or after it
    has been destroyed. Refactor your code to make sure there is a motion manager created by the
    time you invoke this endpoint.
    """)
}
