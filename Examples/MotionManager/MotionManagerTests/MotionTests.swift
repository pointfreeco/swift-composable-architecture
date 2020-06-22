import Combine
import ComposableArchitecture
import ComposableCoreMotion
import CoreMotion
import XCTest

@testable import MotionManagerDemo

class MotionManagerTests: XCTestCase {
  func testExample() {
    let motionSubject = PassthroughSubject<DeviceMotion, Error>()

    var motionManagerIsLive = false

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: .init(
        motionManager: .mock(
          create: { _ in .fireAndForget { motionManagerIsLive = true } },
          destroy: { _ in .fireAndForget { motionManagerIsLive = false } },
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
        XCTAssertEqual(motionManagerIsLive, true)
      },
      .do { motionSubject.send(deviceMotion) },
      .receive(.motionUpdate(.success(deviceMotion))) {
        $0.z = [32]
      },
      .send(.recordingButtonTapped) {
        $0.isRecording = false
        XCTAssertEqual(motionManagerIsLive, false)
      }
    )
  }

  func testFacingDirection() {
    let motionSubject = PassthroughSubject<DeviceMotion, Error>()

    var motionManagerIsLive = false

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: .init(
        motionManager: .mock(
          create: { _ in .fireAndForget { motionManagerIsLive = true } },
          destroy: { _ in .fireAndForget { motionManagerIsLive = false } },
          deviceMotion: { _ in nil },
          startDeviceMotionUpdates: { _, _, _ in motionSubject.eraseToEffect() },
          stopDeviceMotionUpdates: { _ in
            .fireAndForget { motionSubject.send(completion: .finished) }
          }
        )
      )
    )

    let deviceMotion1 = DeviceMotion(
      attitude: .init(quaternion: .init(x: 1, y: 0, z: 0, w: 0)),
      gravity: CMAcceleration(x: 0, y: 0, z: 0),
      heading: 0,
      magneticField: .init(field: .init(x: 0, y: 0, z: 0), accuracy: .high),
      rotationRate: .init(x: 0, y: 0, z: 0),
      timestamp: 0,
      userAcceleration: CMAcceleration(x: 0, y: 0, z: 0)
    )
    var deviceMotion2 = deviceMotion1
    deviceMotion2.attitude = .init(quaternion: .init(x: <#T##Double#>, y: <#T##Double#>, z: <#T##Double#>, w: <#T##Double#>))

    store.assert(
      .send(.recordingButtonTapped) {
        $0.isRecording = true
        XCTAssertEqual(motionManagerIsLive, true)
      },
      .do { motionSubject.send(deviceMotion) },
      .receive(.motionUpdate(.success(deviceMotion))) {
        $0.z = [0]
      },
      .send(.recordingButtonTapped) {
        $0.isRecording = false
        XCTAssertEqual(motionManagerIsLive, false)
      }
    )
  }



      // start
  //initialAttitude Attitude(quaternion: __C.CMQuaternion(x: 0.6494714776423881, y: 0.0026255963956893884, z: -8.671706123902431e-05, w: 0.7603814935004795))
  //newAttitude Attitude(quaternion: __C.CMQuaternion(x: -0.0007262714670632696, y: -5.7950864636874874e-05, z: 6.705383863074782e-05, w: 0.9999997078327616))


      // end
  //    initialAttitude Attitude(quaternion: __C.CMQuaternion(x: 0.6494714776423881, y: 0.0026255963956893884, z: -8.671706123902431e-05, w: 0.7603814935004795))
  //    newAttitude Attitude(quaternion: __C.CMQuaternion(x: 0.03000185075978253, y: 0.06587886308240093, z: 0.9970180422410506, w: -0.026737043251725486))




}
