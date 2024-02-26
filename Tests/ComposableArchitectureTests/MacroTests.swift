#if swift(>=5.9)
  import ComposableArchitecture
  import SwiftUI

  private enum TestViewAction {
    @Reducer
    fileprivate struct Feature {
      struct State {}
      enum Action: ViewAction {
        case view(View)
        enum View { case tap }
      }
      var body: some ReducerOf<Self> { EmptyReducer() }
    }
    @ViewAction(for: Feature.self)
    fileprivate struct FeatureView: View {
      let store: StoreOf<Feature>
      var body: some View {
        Button("Tap") { send(.tap) }
        Button("Tap") { send(.tap, animation: .default) }
        Button("Tap") { send(.tap, transaction: Transaction(animation: .default)) }
      }
    }
  }

  private enum TestObservableEnum_NonObservableCase {
    @Reducer
    fileprivate struct Feature {
      enum State {
        case inert(Int)
      }
      enum Action {}
      var body: some ReducerOf<Self> { EmptyReducer() }
    }
  }

  private enum TestFillInRequirements {
    @Reducer
    struct Feature1 {}
    @Reducer
    struct Feature2 {
      struct State {}
    }
    @Reducer
    struct Feature3 {
      enum Action {}
    }
    @Reducer
    struct Feature4 {
      let body = EmptyReducer<Int, Int>()
    }
    @Reducer
    struct Feature5 {
      typealias State = Int
    }
  }

  private enum TestEnumReducer_Basics {
    @Reducer struct Feature {}
    @Reducer
    enum Destination1 {
      case feature1(Feature)
    }
    @Reducer
    enum Destination2 {
      case feature1(Feature)
      case feature2(Feature)
    }
    @Reducer
    enum Destination3 {
      case feature1(Feature)
      case feature2(Feature)
      case feature3(Feature)
    }
    @Reducer
    enum Destination4 {
      case feature1(Feature)
      case feature2(Feature)
      case feature3(Feature)
      case feature4(Feature)
    }
    @Reducer
    public enum Destination5 {
      case alert(AlertState<Never>)
    }
    @Reducer
    public enum Destination6 {}
  }

  private enum TestEnumReducer_SynthesizedConformances {
    @Reducer
    struct Feature {
    }
    @Reducer(
      state: .codable, .decodable, .encodable, .equatable, .hashable, .sendable,
      action: .equatable, .hashable, .sendable
    )
    enum Destination {
      case feature(Feature)
    }
    func stateRequirements(_: some Codable & Equatable & Hashable & Sendable) {}
    func actionRequirements(_: some Equatable & Hashable & Sendable) {}
    func givenState(_ state: Destination.State) { stateRequirements(state) }
    func givenAction(_ action: Destination.Action) { actionRequirements(action) }
  }
#endif
