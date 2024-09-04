import ComposableArchitecture

private enum TestObservableEnum_CompilerDirective {
  @Reducer
  struct ChildFeature {}
  @ObservableState
  public enum State {
    case child(ChildFeature.State)
    #if os(macOS)
      case mac(ChildFeature.State)
    #elseif os(tvOS)
      case tv(ChildFeature.State)
    #endif
    #if DEBUG
      #if INNER
        case inner(ChildFeature.State)
      #endif
    #endif
  }
}
