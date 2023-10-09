import ComposableArchitecture
import SwiftData
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class SwiftDataTests: XCTestCase {
  let clock = TestClock()

  func testBasics() async {
    let store = TestStore(initialState: LibraryFeature.State()) {
      LibraryFeature()
    } withDependencies: {
      $0.continuousClock = ImmediateClock()
      let container = try! ModelContainer(
        for: Book.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
      )
      $0.modelContainer = container
      let context = ModelContext(container)
      $0.modelContext = ModelContextClient { context }
    }

    await store.send(.addButtonTapped) {
      @Dependency(\.modelContext) var context
      let book = try XCTUnwrap(context().fetch(FetchDescriptor<Book>()).first)
      $0.books = [
        book
      ]
    }
    .finish()
  }

  func testBasics_NonExhaustive() async {
    let store = TestStore(initialState: LibraryFeature.State()) {
      LibraryFeature()
    } withDependencies: {
      $0.continuousClock = ImmediateClock()
      let container = try! ModelContainer(
        for: Book.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
      )
      $0.modelContainer = container
      let context = ModelContext(container)
      $0.modelContext = ModelContextClient { context }
    }
    store.exhaustivity = .off

    await store.send(.addButtonTapped) {
      XCTAssertEqual($0.books.count, 1)
      XCTAssertEqual($0.books[0].title, "")
    }
  }
}
