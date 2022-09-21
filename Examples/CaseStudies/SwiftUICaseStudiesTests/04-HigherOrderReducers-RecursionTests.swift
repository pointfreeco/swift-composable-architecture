import Combine
import ComposableArchitecture
import XCTest
import XCTestDynamicOverlay

@testable import SwiftUICaseStudies

@MainActor
final class RecursionTests: XCTestCase {
  func testAddRow() async {
    let store = TestStore(
      initialState: NestedState(id: UUID()),
      reducer: nestedReducer,
      environment: .unimplemented
    )

    store.environment.uuid = UUID.incrementing

    let id0 = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    let id1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    await store.send(.addRowButtonTapped) {
      $0.rows.append(NestedState(id: id0))
    }

    await store.send(.row(id: id0, action: .addRowButtonTapped)) {
      $0.rows[id: id0]?.rows.append(NestedState(id: id1))
    }
  }

  func testChangeName() async {
    let store = TestStore(
      initialState: NestedState(id: UUID()),
      reducer: nestedReducer,
      environment: .unimplemented
    )

    await store.send(.nameTextFieldChanged("Blob")) {
      $0.name = "Blob"
    }
  }

  func testDeleteRow() async {
    let id0 = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    let id1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let id2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    let store = TestStore(
      initialState: NestedState(
        id: UUID(),
        rows: [
          NestedState(id: id0),
          NestedState(id: id1),
          NestedState(id: id2),
        ]
      ),
      reducer: nestedReducer,
      environment: .unimplemented
    )

    await store.send(.onDelete(IndexSet(integer: 1))) {
      $0.rows.remove(id: id1)
    }
  }
}

extension NestedEnvironment {
  static let unimplemented = Self(
    uuid: XCTUnimplemented("UUID is unimplemented", placeholder: UUID())
  )
}
