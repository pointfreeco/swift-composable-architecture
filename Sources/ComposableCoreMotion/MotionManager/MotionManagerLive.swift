#if canImport(CoreMotion)
  import Combine
  import ComposableArchitecture
  import CoreMotion

  @available(iOS 4, *)
  @available(macCatalyst 13, *)
  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS 2, *)
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
      create: { id in
        .fireAndForget {
          if managers[id] != nil {
            assertionFailure(
              """
              You are attempting to create a motion manager with the id \(id), but there is already \
              a running manager with that id. This is considered a programmer error since you may \
              be accidentally overwriting an existing manager without knowing.

              To fix you should either destroy the existing manager before creating a new one, or \
              you should not try creating a new one before this one is destroyed.
              """)
          }
          managers[id] = CMMotionManager()
        }
      },
      destroy: { id in
        .fireAndForget { managers[id] = nil }
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
          guard let manager = requireMotionManager(id: id)
          else {
            return
          }

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
          guard let manager = requireMotionManager(id: id)
          else {
            return AnyCancellable {}
          }
          guard accelerometerUpdatesSubscribers[id] == nil
          else { return AnyCancellable {} }

          accelerometerUpdatesSubscribers[id] = subscriber
          manager.startAccelerometerUpdates(to: queue) { data, error in
            if let data = data {
              subscriber.send(.init(data))
            } else if let error = error {
              subscriber.send(completion: .failure(error))
            }
          }
          return AnyCancellable {
            manager.stopAccelerometerUpdates()
          }
        }
      },
      startDeviceMotionUpdates: { id, frame, queue in
        return Effect.run { subscriber in
          guard let manager = requireMotionManager(id: id)
          else {
            return AnyCancellable {}
          }
          guard deviceMotionUpdatesSubscribers[id] == nil
          else { return AnyCancellable {} }

          deviceMotionUpdatesSubscribers[id] = subscriber
          manager.startDeviceMotionUpdates(using: frame, to: queue) { data, error in
            if let data = data {
              subscriber.send(.init(data))
            } else if let error = error {
              subscriber.send(completion: .failure(error))
            }
          }
          return AnyCancellable {
            manager.stopDeviceMotionUpdates()
          }
        }
      },
      startGyroUpdates: { id, queue in
        return Effect.run { subscriber in
          guard let manager = requireMotionManager(id: id)
          else {
            return AnyCancellable {}
          }
          guard deviceGyroUpdatesSubscribers[id] == nil
          else { return AnyCancellable {} }

          deviceGyroUpdatesSubscribers[id] = subscriber
          manager.startGyroUpdates(to: queue) { data, error in
            if let data = data {
              subscriber.send(.init(data))
            } else if let error = error {
              subscriber.send(completion: .failure(error))
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
          else {
            couldNotFindMotionManager(id: id)
            return AnyCancellable {}
          }
          guard deviceMagnetometerUpdatesSubscribers[id] == nil
          else { return AnyCancellable {} }

          deviceMagnetometerUpdatesSubscribers[id] = subscriber
          manager.startMagnetometerUpdates(to: queue) { data, error in
            if let data = data {
              subscriber.send(.init(data))
            } else if let error = error {
              subscriber.send(completion: .failure(error))
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
          else {
            couldNotFindMotionManager(id: id)
            return
          }
          manager.stopAccelerometerUpdates()
          accelerometerUpdatesSubscribers[id]?.send(completion: .finished)
          accelerometerUpdatesSubscribers[id] = nil
        }
      },
      stopDeviceMotionUpdates: { id in
        .fireAndForget {
          guard let manager = managers[id]
          else {
            couldNotFindMotionManager(id: id)
            return
          }
          manager.stopDeviceMotionUpdates()
          deviceMotionUpdatesSubscribers[id]?.send(completion: .finished)
          deviceMotionUpdatesSubscribers[id] = nil
        }
      },
      stopGyroUpdates: { id in
        .fireAndForget {
          guard let manager = managers[id]
          else {
            couldNotFindMotionManager(id: id)
            return
          }
          manager.stopGyroUpdates()
          deviceGyroUpdatesSubscribers[id]?.send(completion: .finished)
          deviceGyroUpdatesSubscribers[id] = nil
        }
      },
      stopMagnetometerUpdates: { id in
        .fireAndForget {
          guard let manager = managers[id]
          else {
            couldNotFindMotionManager(id: id)
            return
          }
          manager.stopMagnetometerUpdates()
          deviceMagnetometerUpdatesSubscribers[id]?.send(completion: .finished)
          deviceMagnetometerUpdatesSubscribers[id] = nil
        }
      })

    private static var managers: [AnyHashable: CMMotionManager] = [:]

    private static func requireMotionManager(id: AnyHashable) -> CMMotionManager? {
      if managers[id] == nil {
        couldNotFindMotionManager(id: id)
      }
      return managers[id]
    }
  }

  private var accelerometerUpdatesSubscribers:
    [AnyHashable: Effect<AccelerometerData, Error>.Subscriber] = [:]
  private var deviceMotionUpdatesSubscribers:
    [AnyHashable: Effect<DeviceMotion, Error>.Subscriber] =
      [:]
  private var deviceGyroUpdatesSubscribers: [AnyHashable: Effect<GyroData, Error>.Subscriber] = [:]
  private var deviceMagnetometerUpdatesSubscribers:
    [AnyHashable: Effect<MagnetometerData, Error>.Subscriber] = [:]

  private func couldNotFindMotionManager(id: Any) {
    assertionFailure(
      """
      A motion manager could not be found with the id \(id). This is considered a programmer error. \
      You should not invoke methods on a motion manager before it has been created or after it \
      has been destroyed. Refactor your code to make sure there is a motion manager created by the \
      time you invoke this endpoint.
      """)
  }
#endif
