#if swift(>=5.9) && canImport(Observation)
  import Observation

  protocol ObservableState {
  }

  extension Store: Observable where State: ObservableState {
  }
#endif
