import Combine
import ComposableArchitecture
import ComposableCoreMotion
import CoreMotion
import XCTest

@testable import MotionManagerDemo

class MotionManagerTests: XCTestCase {
  func testExample() {
    let motionSubject = PassthroughSubject<DeviceMotion, Error>()

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: .init(
        motionManager: .mock(
          deviceMotion: { _ in nil },
          startDeviceMotionUpdates: { _, _, _ in motionSubject.eraseToEffect() },
          stopDeviceMotionUpdates: { _ in
            .fireAndForget { motionSubject.send(completion: .finished) }
          }
        )
      )
    )

    let deviceMotion = DeviceMotion(
      attitude: .init(quaternion: .init(x: 1, y: 0, z: 0, w: 0)),
      gravity: CMAcceleration(x: 1, y: 2, z: 3),
      heading: 0,
      magneticField: .init(field: .init(x: 0, y: 0, z: 0), accuracy: .high),
      rotationRate: .init(x: 0, y: 0, z: 0),
      timestamp: 0,
      userAcceleration: CMAcceleration(x: 4, y: 5, z: 6)
    )

    store.assert(
      .send(.recordingButtonTapped) {
        $0.isRecording = true
      },
      .do { motionSubject.send(deviceMotion) },
      .receive(.motionUpdate(.success(deviceMotion))) {
        $0.z = [32]
      },
      .send(.recordingButtonTapped) {
        $0.isRecording = false
      }
    )
  }
}
