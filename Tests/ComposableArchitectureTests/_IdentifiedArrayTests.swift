import XCTest
@testable import ComposableArchitecture

//extension Int: Identifiable { public var id: Self { self } }
struct User: Equatable, Identifiable {
  let id: Int
  var name: String
}

final class IdentifiedArrayOfTests: XCTestCase {
  func testReplaceSubrange() {
    var array: IdentifiedArray = [
      User(id: 3, name: "Blob Sr."),
      User(id: 2, name: "Blob Jr."),
      User(id: 1, name: "Blob"),
    ]

    dump(array)

    array.replaceSubrange(
      0...1,
      with: [
        User(id: 4, name: "Flob IV"),
        User(id: 5, name: "Flob V"),
      ]
    )

    XCTAssertEqual(
      array,
      [
        User(id: 4, name: "Flob IV"),
        User(id: 5, name: "Flob V"),
        User(id: 1, name: "Blob"),
      ]
    )
  }

  func testInsert() {
    var a: IdentifiedArray = [3, 2, 1]
    a.insert(0, at: 3)
    XCTAssertEqual(a, [3, 2, 1, 0])
  }

  func testRemoveAt() {
    var a: IdentifiedArray = [3, 2, 1]
    XCTAssertEqual(a.remove(at: 1), 2)
    XCTAssertEqual(a, [3, 1])
  }

  func testRemoveFirst() {
    var a: IdentifiedArray = [3, 2, 1]
    a.removeFirst()
    XCTAssertEqual(a, [2, 1])
  }

  func testRemoveId() {
    var a: IdentifiedArray = [3, 2, 1]
    XCTAssertEqual(a.remove(id: 2), 2)
    XCTAssertEqual(a, [3, 1])
  }

  func testSort() {
    var a: IdentifiedArray = [3, 2, 1]
    a.sort()
    XCTAssertEqual(a, [1, 2, 3])
  }

  func testCodability() {
    let a: IdentifiedArray = [3, 2, 1]
    XCTAssertEqual(
      a, try JSONDecoder().decode(IdentifiedArray.self, from: JSONEncoder().encode(a))
    )
  }
}
