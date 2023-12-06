import ComposableArchitecture
import XCTest

@MainActor
final class ScopeCacheTests: BaseTCATestCase {
  func testOptionalScope_StoreIfLet() {
    let store = StoreOf<Feature>(initialState: Feature.State(child: Feature.State())) {
      Feature()
    }
    let cancellable = store
      .scope(state: \.child, action: \.child)
      .ifLet { store in
        store.scope(state: \.child, action: \.child)?.send(.tap)
      }
    _ = cancellable
  }


  func testOptionalScope_StoreIfLet_UncachedStore_XYZ() {
    let store = StoreOf<Feature>(initialState: Feature.State(child: Feature.State())) {
      Feature()
    }
    XCTExpectFailure {
      store
        .scope(state: { $0 }, action: { $0 })
        .scope(state: \.child, action: \.child)?
        .send(.tap)
    } issueMatcher: {
      $0.compactDescription == """
        Scoping from uncached StoreOf<Feature> is not compatible with observation. Ensure all \
        store scoping operations in your application have been updated to take key paths and case \
        key paths instead of transform functions, which have been deprecated.
        """
    }
  }

  func testOptionalScope_StoreIfLet_UncachedStore_XYZ111() {
    let store = StoreOf<Feature>(initialState: Feature.State(child: Feature.State())) {
      Feature()
    }
    store
      .scope(state: \.self, action: \.self)
      .scope(state: \.child, action: \.child)?
      .send(.tap)
  }



  func testOptionalScope_StoreIfLet_UncachedStore() {
    let store = StoreOf<Feature>(initialState: Feature.State(child: Feature.State())) {
      Feature()
    }
    XCTExpectFailure {
      let cancellable = store
        .scope(state: { $0 }, action: { $0 })
        .ifLet { store in
          store.scope(state: \.child, action: \.child)?.send(.tap)
        }
      _ = cancellable
    } issueMatcher: {
      $0.compactDescription == """
        Scoping from uncached StoreOf<Feature> is not compatible with observation. Ensure all \
        store scoping operations in your application have been updated to take key paths and case \
        key paths instead of transform functions, which have been deprecated.
        """
    }
  }

  func testIdentifiedArrayScope_CachedStore() {
    let store = StoreOf<Feature>(initialState: Feature.State(rows: [Feature.State()])) {
      Feature()
    }

    let rowsStore = Array(
      store
        .scope(state: \.self, action: \.self)
        .scope(state: \.rows, action: \.rows)
    )
    rowsStore[0].send(.tap)
  }

  func testIdentifiedArrayScope_UncachedStore() {
    let store = StoreOf<Feature>(initialState: Feature.State(rows: [Feature.State()])) {
      Feature()
    }
    XCTExpectFailure {
      _ = Array(
        store
          .scope(state: { $0 }, action: { $0 })
          .scope(state: \.rows, action: \.rows)
      )
    } issueMatcher: {
      $0.compactDescription == """
        Scoping from uncached StoreOf<Feature> is not compatible with observation. Ensure all \
        store scoping operations in your application have been updated to take key paths and case \
        key paths instead of transform functions, which have been deprecated.
        """
    }
  }
}

@Reducer
private struct Feature {
  @ObservableState
  struct State: Identifiable {
    let id = UUID()
    @Presents var child: Feature.State?
    var rows: IdentifiedArrayOf<Feature.State> = []
  }
  indirect enum Action {
    case child(Feature.Action)
    case rows(IdentifiedActionOf<Feature>)
    case tap
  }
  func reduce(into state: inout State, action: Action) -> Effect<Action> { .none }
}
