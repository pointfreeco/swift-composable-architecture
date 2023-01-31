//import Combine
//import ComposableArchitecture
//import XCTest
// 
//@MainActor
//final class NavigationTests: XCTestCase {
//  func testCodability() throws {
//    struct User: Codable, Hashable {
//      var name: String
//      var bio: String
//    }
//    enum Route: Codable, Hashable {
//      case profile(User)
//    }
//
//    let path: NavigationState<Route> = [
//      1: .profile(.init(name: "Blob", bio: "Blobbed around the world."))
//    ]
//    let encoder = JSONEncoder()
//    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
//    let encoded = try encoder.encode(path)
//    XCTAssertNoDifference(
//      String(decoding: encoded, as: UTF8.self),
//      """
//      [
//        {
//          "element" : {
//            "profile" : {
//              "_0" : {
//                "bio" : "Blobbed around the world.",
//                "name" : "Blob"
//              }
//            }
//          },
//          "idString" : "1",
//          "idTypeName" : "Swift.Int"
//        }
//      ]
//      """
//    )
//    let decoded = try JSONDecoder().decode(NavigationState<Route>.self, from: encoded)
//    XCTAssertNoDifference(
//      decoded,
//      path
//    )
//  }
//
//  func testChildActions() async {
//    let store = TestStore(
//      initialState: Feature.State(),
//      reducer: Feature()
//    )
//
//    await store.send(.addButtonTapped) {
//      $0.$path[id: 0] = Child.State()
//    }
//    await store.send(.path(.element(id: 0, .incrementButtonTapped))) {
//      $0.$path[id: 0]?.count = 1
//    }
//    await store.send(.path(.dismiss(id: 0))) {
//      $0.path = []
//    }
//  }
//
//  func testChildEffects() async {
//    let store = TestStore(
//      initialState: Feature.State(),
//      reducer: Feature()
//    )
//    store.dependencies.mainQueue = .immediate
//
//    await store.send(.addButtonTapped) {
//      // TODO: ID should be represented in failure diff
//      $0.$path[id: 0] = Child.State()
//    }
//    await store.send(.path(.element(id: 0, .performButtonTapped)))
//    await store.receive(.path(.element(id: 0, .response(1)))) {
//      $0.$path[id: 0]?.count = 1
//    }
//    await store.send(.path(.dismiss(id: 0))) {
//      $0.path = []
//    }
//  }
//
//  func testChildActionForNilChild() async {
//    let store = TestStore(
//      initialState: Feature.State(),
//      reducer: EmptyReducer<Feature.State, Feature.Action>()
//        .navigationDestination(\.$path, action: /Feature.Action.path) {}
//    )
//    let line = #line - 2
//
//    XCTExpectFailure {
//      $0.compactDescription == """
//        A "navigationDestination" at "\(#fileID):\(line)" received an action for a missing element.
//
//          Action:
//            Feature.Action.path(.element(id:, _: .incrementButtonTapped))
//
//        This is generally considered an application logic error, and can happen for a few reasons:
//
//        • TODO
//        """
//    }
//
//    await store.send(.path(.element(id: 0, .incrementButtonTapped)))
//  }
//
//  func testCancelChildEffectsOnDismiss() async {
//    let store = TestStore(
//      initialState: Feature.State(),
//      reducer: Feature()
//    )
//
//    await store.send(.addButtonTapped) {
//      $0.$path[id: 0] = Child.State()
//    } 
//    await store.send(.path(.element(id: 0, .onAppear)))
//    await store.send(.path(.element(id: 0, .closeButtonTapped)))
//    await store.receive(.path(.dismiss(id: 0))) {
//      $0.path = []
//    }
//  }
//
//  func testCancelAllChildEffects_ResetSetPath() async {
//    let store = TestStore(
//      initialState: Feature.State(),
//      reducer: Feature()
//    )
//
//    await store.send(.addButtonTapped) {
//      $0.$path[id: 0] = Child.State()
//    }
//    await store.send(.path(.element(id: 0, .onAppear)))
//    await store.send(.addButtonTapped) {
//      $0.$path[id: 1] = Child.State()
//    }
//    await store.send(.path(.element(id: 1, .onAppear)))
//    await store.send(.path(.setPath([]))) {
//      $0.path = []
//    }
//  }
//
//  func testMultiChildrenOnStack() async {
//    let store = TestStore(
//      initialState: Feature.State(),
//      reducer: Feature()
//    )
//    store.dependencies.mainQueue = .immediate
//
//    await store.send(.addButtonTapped) {
//      $0.$path[id: 0] = Child.State()
//    }
//    await store.send(.addButtonTapped) {
//      $0.$path[id: 1] = Child.State()
//    }
//
//    await store.send(.path(.element(id: 0, .incrementButtonTapped))) {
//      $0.$path[id: 0]?.count = 1
//    }
//    await store.send(.path(.element(id: 1, .incrementButtonTapped))) {
//      $0.$path[id: 1]?.count = 1
//    }
//
//    await store.send(.path(.element(id: 0, .performButtonTapped)))
//    await store.receive(.path(.element(id: 0, .response(2)))) {
//      $0.$path[id: 0]?.count = 2
//    }
//
//    await store.send(.path(.element(id: 1, .performButtonTapped)))
//    await store.receive(.path(.element(id: 1, .response(2)))) {
//      $0.$path[id: 1]?.count = 2
//    }
//
//    await store.send(.path(.dismiss(id: 1))) {
//      // TODO: APIs to make this nicer:
//      // $0.$path.pop(to: 1)
//      // $0.$path.pop(id: 1)
//      // $0.$path.dismiss(id: 1)
//      // $0.$path.removeAll { $0.id == AnyHashable(1) }
//      $0.$path[id: 1] = nil // this isn't quite right because it doesn't dismiss everything above it
//    }
//    await store.send(.path(.dismiss(id: 0))) {
//      $0.path = []
//    }
//  }
//
//  func testDismissMulti() async {
//    let store = TestStore(
//      initialState: Feature.State(
//        path: [
//          Child.State(),
//          Child.State(),
//        ]
//      ),
//      reducer: Feature()
//    )
//
//    await store.send(.path(.dismiss(id: 0))) {
//      $0.path = []
//    }
//  }
//}
//
//private struct Feature: ReducerProtocol {
//  struct State: Equatable {
//    @NavigationStateOf<Child> var path
//  }
//  enum Action: Equatable {
//    case path(NavigationActionOf<Child>)
//    case addButtonTapped
//  }
//  @Dependency(\.uuid) var uuid
//  var body: some ReducerProtocol<State, Action> {
//    Reduce { state, action in
//      switch action {
//      case .addButtonTapped:
//        state.path.append(Child.State())
//        return .none
//
//      case .path:
//        return .none
//      }
//    }
//    .navigationDestination(\.$path, action: /Action.path) {
//      Child()
//    }
//  }
//
//  struct Destinations: ReducerProtocol {
//    enum State: Equatable, Hashable {}
//    enum Action: Equatable, Hashable {}
//    var body: some ReducerProtocol<State, Action> {
//      EmptyReducer()
//    }
//  }
//}
//
//private struct Child: ReducerProtocol {
//  struct State: Equatable, Hashable {
//    var count = 0
//  }
//  enum Action: Equatable {
//    case closeButtonTapped
//    case incrementButtonTapped
//    case onAppear
//    case performButtonTapped
//    case response(Int)
//  }
//  @Dependency(\.dismiss) var dismiss
//  @Dependency(\.mainQueue) var mainQueue
//  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
//    switch action {
//    case .closeButtonTapped:
//      return .fireAndForget {
//        await self.dismiss()
//      }
//
//    case .incrementButtonTapped:
//      state.count += 1
//      return .none
//
//    case .onAppear:
//      return .run { _ in try await Task.never() }
//
//    case .performButtonTapped:
//      return .run { [count = state.count] send in
//        try await self.mainQueue.sleep(for: .seconds(1))
//        await send(.response(count + 1))
//      }
//
//    case let .response(value):
//      state.count = value
//      return .none
//    }
//  }
//}
