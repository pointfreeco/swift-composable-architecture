import Dispatch

func mainActorASAP(execute block: @escaping @MainActor @Sendable () -> Void) {
  if DispatchQueue.main.getSpecific(key: key) == nil {
    DispatchQueue.main.setSpecific(key: key, value: value)
  }

  if DispatchQueue.getSpecific(key: key) == value {
    MainActor.assumeIsolated { block() }
  } else {
    DispatchQueue.main.async {
      MainActor.assumeIsolated {
        block()
      }
    }
  }
}

private let key = DispatchSpecificKey<UInt8>()
private let value: UInt8 = 0
