import ComposableArchitecture

@Reducer struct OtherFeature {}

@Reducer enum Destination {
  case other(OtherFeature)

  #if !PRODUCTION_BUILD
    @ReducerCaseIgnored case debug
  #endif
}
