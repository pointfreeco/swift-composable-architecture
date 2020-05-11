import Combine
import ComposableArchitecture
import CoreMotion
import XCTest

@testable import MotionManager

class MotionManagerTests: XCTestCase {
  func testExample() {
    let motionSubject = PassthroughSubject<MotionClient.Action, MotionClient.Error>()
    var motionUpdatesStarted = false

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: .init(
        motionClient: .mock(
          create: { _ in motionSubject.eraseToEffect() },
          startDeviceMotionUpdates: { _ in .fireAndForget { motionUpdatesStarted = true } },
          stopDeviceMotionUpdates: { _ in
            .fireAndForget { motionSubject.send(completion: .finished) }
          }
        )
      )
    )

    let deviceMotion = DeviceMotion(
      gravity: CMAcceleration(x: 1, y: 2, z: 3),
      userAcceleration: CMAcceleration(x: 4, y: 5, z: 6)
    )

    store.assert(
      .send(.onAppear),
      .send(.recordingButtonTapped) {
        $0.isRecording = true
        XCTAssertTrue(motionUpdatesStarted)
      },
      .do { motionSubject.send(.motionUpdate(deviceMotion)) },
      .receive(.motionClient(.success(.motionUpdate(deviceMotion)))) {
        $0.z = [32]
      },
      .send(.recordingButtonTapped) {
        $0.isRecording = false
      }
    )
  }
}
