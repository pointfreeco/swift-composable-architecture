#if swift(>=5.9)
  import ComposableArchitecture

  private enum TestEnumReducer_CompilerDirective {
    @Reducer
    struct ChildFeature {}
    enum Options {}

    @Reducer
    enum Feature {
      case child(ChildFeature)

      #if os(macOS)
        case mac(ChildFeature)
        case macAlert(AlertState<Options>)
      #elseif os(iOS)
        case phone(ChildFeature)
      #else
        case other(ChildFeature)
        case another
      #endif

      #if DEBUG
        #if INNER
          case inner(ChildFeature)
          case innerDialog(ConfirmationDialogState<Options>)
        #endif
      #endif
    }
  }

  private enum TestEnumReducer_DefaultInitializer {
    @Reducer
    struct Feature {
      let context: String
    }
    @Reducer
    enum Destination1 {
      case feature1(Feature = Feature(context: "context"))
    }
  }
#endif
