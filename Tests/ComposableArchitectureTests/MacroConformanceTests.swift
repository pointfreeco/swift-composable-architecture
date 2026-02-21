import ComposableArchitecture

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
}

extension TestEnumReducer_SynthesizedConformances.Destination.State: Codable, Hashable, Sendable {}
extension TestEnumReducer_SynthesizedConformances.Destination.Action: Hashable, Sendable {}
