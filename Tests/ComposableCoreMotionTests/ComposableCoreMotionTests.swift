#if canImport(CoreMotion)
  import XCTest

  @testable import ComposableCoreMotion

  class ComposableCoreMotionTests: XCTestCase {
    func testQuaternionInverse() {
      let q = CMQuaternion(x: 1, y: 2, z: 3, w: 4)
      let inv = q.inverse
      let result = q.multiplied(by: inv)

      XCTAssertEqual(result.x, 0)
      XCTAssertEqual(result.y, 0)
      XCTAssertEqual(result.z, 0)
      XCTAssertEqual(result.w, 1)
    }

    func testQuaternionMultiplication() {
      let q1 = CMQuaternion(x: 1, y: 2, z: 3, w: 4)
      let q2 = CMQuaternion(x: -4, y: 3, z: -2, w: 1)
      let result = q1.multiplied(by: q2)

      XCTAssertEqual(result.x, -28)
      XCTAssertEqual(result.y, 4)
      XCTAssertEqual(result.z, 6)
      XCTAssertEqual(result.w, 8)
    }

    func testRollPitchYaw() {
      let q1 = Attitude(quaternion: .init(x: 1, y: 0, z: 0, w: 0))
      let q2 = Attitude(quaternion: .init(x: 0, y: 1, z: 0, w: 0))
      let q3 = Attitude(quaternion: .init(x: 0, y: 0, z: 1, w: 0))
      let q4 = Attitude(quaternion: .init(x: 0, y: 0, z: 0, w: 1))

      XCTAssertEqual(q1.roll, Double.pi)
      XCTAssertEqual(q1.pitch, 0)
      XCTAssertEqual(q1.yaw, 0)

      XCTAssertEqual(q2.roll, Double.pi)
      XCTAssertEqual(q2.pitch, 0)
      XCTAssertEqual(q2.yaw, Double.pi)

      XCTAssertEqual(q3.roll, 0)
      XCTAssertEqual(q3.pitch, 0)
      XCTAssertEqual(q3.yaw, Double.pi)

      XCTAssertEqual(q4.roll, 0)
      XCTAssertEqual(q4.pitch, 0)
      XCTAssertEqual(q4.yaw, 0)
    }
  }
#endif
