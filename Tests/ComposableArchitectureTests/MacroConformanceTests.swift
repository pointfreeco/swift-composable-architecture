import ComposableArchitecture

#if swift(>=6)
  private enum TestEnumReducer_SynthesizedConformances {
    @Reducer
    struct Feature {
    }
    @Reducer
    enum Destination {
      case feature(Feature)
    }
    func stateRequirements(_: some Codable & Hashable & Sendable) {}
    func actionRequirements(_: some Hashable & Sendable) {}
    func givenState(_ state: Destination.State) { stateRequirements(state) }
    func givenAction(_ action: Destination.Action) { actionRequirements(action) }

    extension Destination.State: Codable, Hashable, Sendable {}
    extension Destination.Action: Hashable, Sendable {}
  }
#else
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
    func stateRequirements(_: some Codable & Hashable & Sendable) {}
    func actionRequirements(_: some Hashable & Sendable) {}
    func givenState(_ state: Destination.State) { stateRequirements(state) }
    func givenAction(_ action: Destination.Action) { actionRequirements(action) }
  }
#endif
