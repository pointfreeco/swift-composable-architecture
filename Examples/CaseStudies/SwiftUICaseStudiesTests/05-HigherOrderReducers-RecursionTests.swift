import ComposableArchitecture
import Foundation
import Testing

@testable import SwiftUICaseStudies

@MainActor
struct RecursionTests {
  @Test
  func addRow() async {
    let store = TestStore(initialState: Nested.State(id: UUID())) {
      Nested()
    } withDependencies: {
      $0.uuid = .incrementing
    }

    await store.send(.addRowButtonTapped) {
      $0.rows.append(Nested.State(id: UUID(0)))
    }

    await store.send(\.rows[id: UUID(0)].addRowButtonTapped) {
      $0.rows[id: UUID(0)]?.rows.append(Nested.State(id: UUID(1)))
    }
  }

  @Test
  func changeName() async {
    let store = TestStore(initialState: Nested.State(id: UUID())) {
      Nested()
    }

    await store.send(.nameTextFieldChanged("Blob")) {
      $0.name = "Blob"
    }
  }

  @Test
  func deleteRow() async {
    let store = TestStore(
      initialState: Nested.State(
        id: UUID(),
        rows: [
          Nested.State(id: UUID(0)),
          Nested.State(id: UUID(1)),
          Nested.State(id: UUID(2)),
        ]
      )
    ) {
      Nested()
    }

    await store.send(.onDelete(IndexSet(integer: 1))) {
      $0.rows.remove(id: UUID(1))
    }
  }
}
