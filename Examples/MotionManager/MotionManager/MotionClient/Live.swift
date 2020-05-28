import Combine
import ComposableArchitecture
import CoreMotion

extension MotionClient {
  static let live = MotionClient(
    create: { id in
      .run { subscriber in
        let manager = MotionManager(
          manager: CMMotionManager(),
          handler: { motion, error in
            switch (motion, error) {
            case let (.some(motion), .none):
              subscriber.send(.motionUpdate(DeviceMotion(deviceMotion: motion)))
            case let (_, .some(error)):
              subscriber.send(completion: .failure(.motionUpdateFailed("\(error)")))
            case (.none, .none):
              fatalError("It should not be possible to have both a nil result and nil error.")
            }
          })
        guard manager.isDeviceMotionAvailable else {
          subscriber.send(completion: .failure(.notAvailable))
          return AnyCancellable {}
        }
        motionManagers[id] = manager
        return AnyCancellable { motionManagers[id] = nil }
      }
    },
    startDeviceMotionUpdates: { id in
      .fireAndForget { motionManagers[id]?.startMotionUpdates() }
    },
    stopDeviceMotionUpdates: { id in
      .fireAndForget { motionManagers[id]?.stopMotionUpdates() }
    })
}

private final class MotionManager {
  init(manager: CMMotionManager, handler: @escaping CMDeviceMotionHandler) {
    self.manager = manager
    self.handler = handler
  }

  var manager: CMMotionManager
  var handler: CMDeviceMotionHandler

  var isDeviceMotionAvailable: Bool { self.manager.isDeviceMotionAvailable }

  func startMotionUpdates() {
    self.manager.startDeviceMotionUpdates(
      using: .xArbitraryZVertical,
      to: .main,
      withHandler: self.handler
    )
  }

  func stopMotionUpdates() {
    self.manager.stopDeviceMotionUpdates()
  }
}

private var motionManagers: [AnyHashable: MotionManager] = [:]
