//import XCTest
//@testable import ComposableArchitecture
//
//extension Int: Identifiable { public var id: Self { self } }
//
//final class _IdentifiedArrayTests: XCTestCase {
//  func testInsert() {
//    var a: _IdentifiedArray<Int> = [3, 2, 1]
//    a.insert(0, at: 3)
//    XCTAssertEqual(a, [3, 2, 1, 0])
//  }
//
//  func testRemoveAt() {
//    var a: _IdentifiedArray = [3, 2, 1]
//    XCTAssertEqual(a.remove(at: 1), 2)
//    XCTAssertEqual(a, [3, 1])
//  }
//
//  func testRemoveFirst() {
//    var a: _IdentifiedArray<Int> = [3, 2, 1]
//    a.removeFirst()
//    XCTAssertEqual(a, [2, 1])
//  }
//
//  func testRemoveId() {
//    var a: _IdentifiedArray = [3, 2, 1]
//    XCTAssertEqual(a.remove(id: 2), 2)
//    XCTAssertEqual(a, [3, 1])
//  }
//
//  func testSort() {
//    var a: _IdentifiedArray<Int> = [3, 2, 1]
//    a.sort()
//    XCTAssertEqual(a, [1, 2, 3])
//  }
//}
