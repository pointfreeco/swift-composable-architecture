#if swift(>=5.9)
  @_spi(Internals) import ComposableArchitecture
  import XCTest

  final class ScopeCacheTests: BaseTCATestCase {
    @available(*, deprecated)
    @MainActor
    func testOptionalScope_UncachedStore() {
      let store = StoreOf<Feature>(initialState: Feature.State(child: Feature.State())) {
      }

      XCTExpectFailure {
        _ =
          store
          .scope(state: { $0 }, action: { $0 })
          .scope(state: \.child, action: \.child.presented)?
          .send(.show)
      } issueMatcher: {
        $0.compactDescription == """
          Scoping from uncached StoreOf<Feature> is not compatible with observation.

          This can happen for one of two reasons:

          • A parent view scopes on a store using transform functions, which has been \
          deprecated, instead of with key paths and case paths. Read the migration guide for 1.5 \
          to update these scopes: https://pointfreeco.github.io/swift-composable-architecture/\
          main/documentation/composablearchitecture/migratingto1.5

          • A parent feature is using deprecated navigation APIs, such as 'IfLetStore', \
          'SwitchStore', 'ForEachStore', or any navigation view modifiers taking stores instead of \
          bindings. Read the migration guide for 1.7 to update those APIs: \
          https://pointfreeco.github.io/swift-composable-architecture/main/documentation/\
          composablearchitecture/migratingto1.7
          """
      }
      store.send(.child(.dismiss))
    }

    @MainActor
    func testOptionalScope_CachedStore() {
      #if DEBUG
        let store = StoreOf<Feature>(initialState: Feature.State(child: Feature.State())) {
        }
        store
          .scope(state: \.self, action: \.self)
          .scope(state: \.child, action: \.child.presented)?
          .send(.show)
      #endif
    }

    @MainActor
    func testOptionalScope_StoreIfLet() {
      #if DEBUG
        let store = StoreOf<Feature>(initialState: Feature.State(child: Feature.State())) {
          Feature()
        }
        let cancellable =
          store
          .scope(state: \.child, action: \.child.presented)
          .ifLet { store in
            store.scope(state: \.child, action: \.child.presented)?.send(.show)
          }
        _ = cancellable
      #endif
    }

    @available(*, deprecated)
    @MainActor
    func testOptionalScope_StoreIfLet_UncachedStore() {
      let store = StoreOf<Feature>(initialState: Feature.State(child: Feature.State())) {
      }
      XCTExpectFailure {
        let cancellable =
          store
          .scope(state: { $0 }, action: { $0 })
          .ifLet { store in
            store.scope(state: \.child, action: \.child.presented)?.send(.show)
          }
        _ = cancellable
      } issueMatcher: {
        $0.compactDescription == """
          Scoping from uncached StoreOf<Feature> is not compatible with observation.

          This can happen for one of two reasons:

          • A parent view scopes on a store using transform functions, which has been \
          deprecated, instead of with key paths and case paths. Read the migration guide for 1.5 \
          to update these scopes: https://pointfreeco.github.io/swift-composable-architecture/\
          main/documentation/composablearchitecture/migratingto1.5

          • A parent feature is using deprecated navigation APIs, such as 'IfLetStore', \
          'SwitchStore', 'ForEachStore', or any navigation view modifiers taking stores instead of \
          bindings. Read the migration guide for 1.7 to update those APIs: \
          https://pointfreeco.github.io/swift-composable-architecture/main/documentation/\
          composablearchitecture/migratingto1.7
          """
      }
    }

    @MainActor
    func testIdentifiedArrayScope_CachedStore() {
      #if DEBUG
        let store = StoreOf<Feature>(initialState: Feature.State(rows: [Feature.State()])) {
        }

        let rowsStore = Array(
          store
            .scope(state: \.self, action: \.self)
            .scope(state: \.rows, action: \.rows)
        )
        rowsStore[0].send(.show)
      #endif
    }

    @available(*, deprecated)
    @MainActor
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
          Scoping from uncached StoreOf<Feature> is not compatible with observation.

          This can happen for one of two reasons:

          • A parent view scopes on a store using transform functions, which has been \
          deprecated, instead of with key paths and case paths. Read the migration guide for 1.5 \
          to update these scopes: https://pointfreeco.github.io/swift-composable-architecture/\
          main/documentation/composablearchitecture/migratingto1.5

          • A parent feature is using deprecated navigation APIs, such as 'IfLetStore', \
          'SwitchStore', 'ForEachStore', or any navigation view modifiers taking stores instead of \
          bindings. Read the migration guide for 1.7 to update those APIs: \
          https://pointfreeco.github.io/swift-composable-architecture/main/documentation/\
          composablearchitecture/migratingto1.7
          """
      }
    }
  }

  @Reducer
  private struct Feature {
    @ObservableState
    struct State: Identifiable, Equatable {
      let id = UUID()
      @Presents var child: Feature.State?
      var rows: IdentifiedArrayOf<Feature.State> = []
    }
    indirect enum Action {
      case child(PresentationAction<Feature.Action>)
      case dismiss
      case rows(IdentifiedActionOf<Feature>)
      case show
    }
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .child(.presented(.dismiss)):
          state.child = nil
          return .none
        case .child:
          return .none
        case .dismiss:
          return .none
        case .rows:
          return .none
        case .show:
          state.child = Feature.State()
          return .none
        }
      }
      .ifLet(\.$child, action: \.child) {
        Feature()
      }
      .forEach(\.rows, action: \.rows) {
        Feature()
      }
    }
  }
#endif
