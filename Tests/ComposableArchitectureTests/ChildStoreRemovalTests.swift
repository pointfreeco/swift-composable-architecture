import ComposableArchitecture
import SwiftUI
import XCTest

final class ChildStoreRemovalTests: BaseTCATestCase {
  // `Map(selection:)` reports a change of selection as two writes in a row: `nil` (the old marker
  // is deselected), then the new value. A feature that drives a sheet from the selection therefore
  // sees its presented state go `nil` and back to non-`nil` within a single run loop pass, and
  // SwiftUI only ever renders the final, non-`nil` state.
  @MainActor
  func testPresentedStore_NilAndBackAgain_LaterReadVendsSameStore() async throws {
    guard #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) else {
      throw XCTSkip("Requires SwiftUI.Bindable")
    }
    let store = Store(initialState: Parent.State(child: Child.State())) {
      Parent()
    }
    // The child store that `sheet(item: $store.scope(\.child, action: \.child))` presents.
    _ = try XCTUnwrap(SwiftUI.Bindable(store).scope(\.child, action: \.child).wrappedValue)

    store.send(.dismissChild)
    store.send(.presentChild)
    // What the sheet reads on the render that follows the two writes above.
    let presented = try XCTUnwrap(
      SwiftUI.Bindable(store).scope(\.child, action: \.child).wrappedValue
    )

    // Any later render reads the binding again, for example after an unrelated state change.
    try await Task.sleep(for: .milliseconds(500))
    store.send(.unrelatedButtonTapped)
    let presentedLater = try XCTUnwrap(
      SwiftUI.Bindable(store).scope(\.child, action: \.child).wrappedValue
    )

    // `sheet(item:)` identifies its item by the store's identity. A different store here dismisses
    // the sheet and presents a new one, although nothing about the presentation has changed.
    XCTAssertTrue(presented === presentedLater)

    store.send(.child(.dismiss))
  }

  @MainActor
  func testPresentedStore_PresentedAgainWithinRemovalDelay_LaterReadVendsSameStore() async throws {
    guard #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) else {
      throw XCTSkip("Requires SwiftUI.Bindable")
    }
    let store = Store(initialState: Parent.State(child: Child.State())) {
      Parent()
    }
    _ = try XCTUnwrap(SwiftUI.Bindable(store).scope(\.child, action: \.child).wrappedValue)

    // This time the parent is rendered while the child is dismissed, so the dismissed child's
    // store is no longer cached, and presenting again creates a new one.
    store.send(.dismissChild)
    XCTAssertNil(SwiftUI.Bindable(store).scope(\.child, action: \.child).wrappedValue)
    store.send(.presentChild)
    let presented = try XCTUnwrap(
      SwiftUI.Bindable(store).scope(\.child, action: \.child).wrappedValue
    )

    // The removal scheduled by the dismissed child must not remove the new child's store.
    try await Task.sleep(for: .milliseconds(500))
    store.send(.unrelatedButtonTapped)
    let presentedLater = try XCTUnwrap(
      SwiftUI.Bindable(store).scope(\.child, action: \.child).wrappedValue
    )
    XCTAssertTrue(presented === presentedLater)

    store.send(.child(.dismiss))
  }

  @MainActor
  func testPresentedStore_NilAndBackAgain_RemovedAfterLaterDismissal() async throws {
    guard #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) else {
      throw XCTSkip("Requires SwiftUI.Bindable")
    }
    let store = Store(initialState: Parent.State(child: Child.State())) {
      Parent()
    }
    weak var presented: Store<Child.State, Child.Action>?
    presented = SwiftUI.Bindable(store).scope(\.child, action: \.child).wrappedValue
    XCTAssertNotNil(presented)

    store.send(.dismissChild)
    store.send(.presentChild)
    try await Task.sleep(for: .milliseconds(500))
    XCTAssertNotNil(presented)

    // The store that was kept is still removed from its parent once its state is gone for good.
    store.send(.dismissChild)
    try await Task.sleep(for: .milliseconds(500))
    XCTAssertNil(presented)
  }

  @MainActor
  func testElementStore_ScopedAfterElementIsRemoved_IsRemoved() async throws {
    let store = Store(initialState: Rows.State(rows: [Child.State(id: 1)])) {
      Rows()
    }
    weak var row: Store<Child.State, Child.Action>?
    do {
      // A collection that still lists an element that is removed before the element's store is
      // scoped, like a `ForEach` that renders a row while it is being removed.
      let rows: some RandomAccessCollection<Store<Child.State, Child.Action>> = store.scope(
        \.rows,
        action: \.rows
      )
      store.send(.removeAllRows)
      row = rows[rows.startIndex]
    }
    XCTAssertNotNil(row)

    // A store that is invalid from the start is removed from its parent like any other.
    try await Task.sleep(for: .milliseconds(500))
    XCTAssertNil(row)
  }
}

@Reducer
private struct Parent {
  @ObservableState
  struct State: Equatable {
    @Presents var child: Child.State?
    var unrelatedCount = 0
  }
  enum Action {
    case child(PresentationAction<Child.Action>)
    case dismissChild
    case presentChild
    case unrelatedButtonTapped
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .child:
        return .none
      case .dismissChild:
        state.child = nil
        return .none
      case .presentChild:
        state.child = Child.State()
        return .none
      case .unrelatedButtonTapped:
        state.unrelatedCount += 1
        return .none
      }
    }
    .ifLet(\.$child, action: \.child) {
      Child()
    }
  }
}

@Reducer
private struct Rows {
  @ObservableState
  struct State: Equatable {
    var rows: IdentifiedArrayOf<Child.State> = []
  }
  enum Action {
    case removeAllRows
    case rows(IdentifiedActionOf<Child>)
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .removeAllRows:
        state.rows.removeAll()
        return .none
      case .rows:
        return .none
      }
    }
    .forEach(\.rows, action: \.rows) {
      Child()
    }
  }
}

@Reducer
private struct Child {
  @ObservableState
  struct State: Equatable, Identifiable {
    var id = 0
  }
  enum Action {}
  var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}
