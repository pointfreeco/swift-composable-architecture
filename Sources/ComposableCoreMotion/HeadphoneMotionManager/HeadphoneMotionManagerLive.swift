#if swift(>=5.3)
  import Combine
  import ComposableArchitecture
  import CoreMotion

  @available(iOS 14, *)
  @available(macCatalyst 14, *)
  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS 7, *)
  extension HeadphoneMotionManager {
    public static let live = HeadphoneMotionManager(
      create: { id in
        Effect.run { subscriber in
          if dependencies[id] != nil {
            assertionFailure(
              """
              You are attempting to create a headphone motion manager with the id \(id), but there \
              is already a running manager with that id. This is considered a programmer error \
              since you may be accidentally overwriting an existing manager without knowing.

              To fix you should either destroy the existing manager before creating a new one, or \
              you should not try creating a new one before this one is destroyed.
              """)
          }

          let manager = CMHeadphoneMotionManager()
          var delegate = Delegate(subscriber)
          manager.delegate = delegate

          dependencies[id] = Dependencies(
            delegate: delegate,
            manager: manager,
            subscriber: subscriber
          )

          return AnyCancellable {
            dependencies[id] = nil
          }
        }
      },
      destroy: { id in
        .fireAndForget { dependencies[id] = nil }
      },
      deviceMotion: { id in
        requireHeadphoneMotionManager(id: id)?.deviceMotion.map(DeviceMotion.init)
      },
      isDeviceMotionActive: { id in
        requireHeadphoneMotionManager(id: id)?.isDeviceMotionActive ?? false
      },
      isDeviceMotionAvailable: { id in
        requireHeadphoneMotionManager(id: id)?.isDeviceMotionAvailable ?? false
      },
      startDeviceMotionUpdates: { id, queue in
        return Effect.run { subscriber in
          guard let manager = requireHeadphoneMotionManager(id: id)
          else {
            couldNotFindHeadphoneMotionManager(id: id)
            return AnyCancellable {}
          }
          guard deviceMotionUpdatesSubscribers[id] == nil
          else { return AnyCancellable {} }

          deviceMotionUpdatesSubscribers[id] = subscriber
          manager.startDeviceMotionUpdates(to: queue) { data, error in
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
      stopDeviceMotionUpdates: { id in
        .fireAndForget {
          guard let manager = requireHeadphoneMotionManager(id: id)
          else {
            couldNotFindHeadphoneMotionManager(id: id)
            return
          }
          manager.stopDeviceMotionUpdates()
          deviceMotionUpdatesSubscribers[id]?.send(completion: .finished)
          deviceMotionUpdatesSubscribers[id] = nil
        }
      }
    )

    private class Delegate: NSObject, CMHeadphoneMotionManagerDelegate {
      let subscriber: Effect<HeadphoneMotionManager.Action, Never>.Subscriber

      init(_ subscriber: Effect<HeadphoneMotionManager.Action, Never>.Subscriber) {
        self.subscriber = subscriber
      }

      func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        self.subscriber.send(.didConnect)
      }

      func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        self.subscriber.send(.didDisconnect)
      }
    }

    private struct Dependencies {
      let delegate: Delegate
      let manager: CMHeadphoneMotionManager
      let subscriber: Effect<HeadphoneMotionManager.Action, Never>.Subscriber
    }

    private static var dependencies: [AnyHashable: Dependencies] = [:]

    private static func requireHeadphoneMotionManager(id: AnyHashable)
    -> CMHeadphoneMotionManager? {
      if dependencies[id] == nil {
        couldNotFindHeadphoneMotionManager(id: id)
      }
      return dependencies[id]?.manager
    }
  }

  private var deviceMotionUpdatesSubscribers: [AnyHashable: Effect<DeviceMotion, Error>.Subscriber]
    = [:]

  private func couldNotFindHeadphoneMotionManager(id: Any) {
    assertionFailure(
      """
      A headphone motion manager could not be found with the id \(id). This is considered a \
      programmer error. You should not invoke methods on a motion manager before it has been \
      created or after it has been destroyed. Refactor your code to make sure there is a headphone \
      motion manager created by the time you invoke this endpoint.
      """)
  }
#endif
