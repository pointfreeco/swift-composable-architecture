import ComposableArchitecture
import XCTest

@MainActor
final class ScopeCacheTests: BaseTCATestCase {
  func testOptionalScope_UncachedStore() {
    #if DEBUG
      let store = StoreOf<Feature>(initialState: Feature.State(child: Feature.State())) {
        Feature()
      }
      XCTExpectFailure {
        _ =
          store
          .scope(state: { $0 }, action: { $0 })
          .scope(state: \.child, action: \.child)?
          .send(.tap)
      } issueMatcher: {
        $0.compactDescription == """
          Scoping from uncached StoreOf<Feature> is not compatible with observation. Ensure that all \
          parent store scoping operations take key paths and case key paths instead of transform \
          functions, which have been deprecated.
          """
      }
    #endif
  }

  func testOptionalScope_CachedStore() {
    #if DEBUG
      let store = StoreOf<Feature>(initialState: Feature.State(child: Feature.State())) {
        Feature()
      }
      store
        .scope(state: \.self, action: \.self)
        .scope(state: \.child, action: \.child)?
        .send(.tap)
    #endif
  }

  func testOptionalScope_StoreIfLet() {
    #if DEBUG
      let store = StoreOf<Feature>(initialState: Feature.State(child: Feature.State())) {
        Feature()
      }
      let cancellable =
        store
        .scope(state: \.child, action: \.child)
        .ifLet { store in
          store.scope(state: \.child, action: \.child)?.send(.tap)
        }
      _ = cancellable
    #endif
  }

  func testOptionalScope_StoreIfLet_UncachedStore() {
    #if DEBUG
      let store = StoreOf<Feature>(initialState: Feature.State(child: Feature.State())) {
        Feature()
      }
      XCTExpectFailure {
        let cancellable =
          store
          .scope(state: { $0 }, action: { $0 })
          .ifLet { store in
            store.scope(state: \.child, action: \.child)?.send(.tap)
          }
        _ = cancellable
      } issueMatcher: {
        $0.compactDescription == """
          Scoping from uncached StoreOf<Feature> is not compatible with observation. Ensure that all \
          parent store scoping operations take key paths and case key paths instead of transform \
          functions, which have been deprecated.
          """
      }
    #endif
  }

  func testIdentifiedArrayScope_CachedStore() {
    #if DEBUG
      let store = StoreOf<Feature>(initialState: Feature.State(rows: [Feature.State()])) {
        Feature()
      }

      let rowsStore = Array(
        store
          .scope(state: \.self, action: \.self)
          .scope(state: \.rows, action: \.rows)
      )
      rowsStore[0].send(.tap)
    #endif
  }

  func testIdentifiedArrayScope_UncachedStore() {
    #if DEBUG
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
          Scoping from uncached StoreOf<Feature> is not compatible with observation. Ensure that all \
          parent store scoping operations take key paths and case key paths instead of transform \
          functions, which have been deprecated.
          """
      }
    #endif
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
