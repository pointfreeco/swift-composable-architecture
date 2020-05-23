@testable import ComposableCoreMotion
import XCTest

class ComposableCoreMotionTests: XCTestCase {
  func testQ() {

    let a = Attitude(quaternion: CMQuaternion(x: 0.46291, y: -0.3086067, z: 0.7715167, w: 0.3086067))

    let tmp = a.rotationMatrix
    print(a.roll)
    print(a.pitch)
    print(a.yaw)
    print("!")
  }
}
