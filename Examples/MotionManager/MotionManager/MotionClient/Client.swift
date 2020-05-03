import Combine
import ComposableArchitecture
import CoreMotion

struct MotionClient {
  enum Action: Equatable {
    case motionUpdate(DeviceMotion)
  }

  enum Error: Swift.Error, Equatable {
    case motionUpdateFailed(String)
    case notAvailable
  }

  func create(id: AnyHashable) -> Effect<Action, Error> {
    self.create(id)
  }

  func startDeviceMotionUpdates(id: AnyHashable) -> Effect<Never, Never> {
    self.startDeviceMotionUpdates(id)
  }

  func stopDeviceMotionUpdates(id: AnyHashable) -> Effect<Never, Never> {
    self.stopDeviceMotionUpdates(id)
  }

  var create: (AnyHashable) -> Effect<Action, Error>
  var startDeviceMotionUpdates: (AnyHashable) -> Effect<Never, Never>
  var stopDeviceMotionUpdates: (AnyHashable) -> Effect<Never, Never>
}
