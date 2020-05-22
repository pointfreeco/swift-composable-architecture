import XCTest

@testable import ComposableArchitecture

final class IdentifiedArrayTests: XCTestCase {
  func testIdSubscript() {
    struct User: Equatable, Identifiable {
      let id: Int
      var name: String
    }

    let array: IdentifiedArray = [User(id: 1, name: "Blob")]

    XCTAssertEqual(array[id: 1], .some(User(id: 1, name: "Blob")))
  }

  func testRemoveId() {
    struct User: Equatable, Identifiable {
      let id: Int
      var name: String
    }

    var array: IdentifiedArray = [User(id: 1, name: "Blob")]

    XCTAssertEqual(array.remove(id: 1), User(id: 1, name: "Blob"))
    XCTAssertEqual(array, [])
  }

  func testInsert() {
    struct User: Equatable, Identifiable {
      let id: Int
      var name: String
    }

    var array: IdentifiedArray = [User(id: 1, name: "Blob")]

    array.insert(User(id: 2, name: "Blob Jr."), at: 0)
    XCTAssertEqual(array, [User(id: 2, name: "Blob Jr."), User(id: 1, name: "Blob")])
  }

  func testInsertContentsOf() {
    struct User: Equatable, Identifiable {
      let id: Int
      var name: String
    }

    var array: IdentifiedArray = [User(id: 1, name: "Blob")]

    array.insert(contentsOf: [User(id: 3, name: "Blob Sr."), User(id: 2, name: "Blob Jr.")], at: 0)
    XCTAssertEqual(
      array,
      [User(id: 3, name: "Blob Sr."), User(id: 2, name: "Blob Jr."), User(id: 1, name: "Blob")]
    )
  }

  func testRemoveAt() {
    struct User: Equatable, Identifiable {
      let id: Int
      var name: String
    }

    var array: IdentifiedArray = [
      User(id: 3, name: "Blob Sr."),
      User(id: 2, name: "Blob Jr."),
      User(id: 1, name: "Blob"),
    ]

    array.remove(at: 1)
    XCTAssertEqual(array, [User(id: 3, name: "Blob Sr."), User(id: 1, name: "Blob")])
  }

  func testRemoveAllWhere() {
    struct User: Equatable, Identifiable {
      let id: Int
      var name: String
    }

    var array: IdentifiedArray = [
      User(id: 3, name: "Blob Sr."),
      User(id: 2, name: "Blob Jr."),
      User(id: 1, name: "Blob"),
    ]

    array.removeAll(where: { $0.name.starts(with: "Blob ") })
    XCTAssertEqual(array, [User(id: 1, name: "Blob")])
  }

  func testRemoveAtOffsets() {
    struct User: Equatable, Identifiable {
      let id: Int
      var name: String
    }

    var array: IdentifiedArray = [
      User(id: 3, name: "Blob Sr."),
      User(id: 2, name: "Blob Jr."),
      User(id: 1, name: "Blob"),
    ]

    array.remove(atOffsets: [0, 2])
    XCTAssertEqual(array, [User(id: 2, name: "Blob Jr.")])
  }

  func testMoveFromOffsets() {
    struct User: Equatable, Identifiable {
      let id: Int
      var name: String
    }

    var array: IdentifiedArray = [
      User(id: 3, name: "Blob Sr."),
      User(id: 2, name: "Blob Jr."),
      User(id: 1, name: "Blob"),
    ]

    array.move(fromOffsets: [0], toOffset: 2)
    XCTAssertEqual(
      array,
      [User(id: 2, name: "Blob Jr."), User(id: 3, name: "Blob Sr."), User(id: 1, name: "Blob")]
    )
  }

  func testReplaceSubrange() {
    struct User: Equatable, Identifiable {
      let id: Int
      var name: String
    }

    var array: IdentifiedArray = [
      User(id: 3, name: "Blob Sr."),
      User(id: 2, name: "Blob Jr."),
      User(id: 1, name: "Blob"),
      User(id: 2, name: "Blob Jr."),
    ]

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
        User(id: 4, name: "Flob IV"), User(id: 5, name: "Flob V"), User(id: 1, name: "Blob"),
        User(id: 2, name: "Blob Jr."),
      ]
    )
  }
}
