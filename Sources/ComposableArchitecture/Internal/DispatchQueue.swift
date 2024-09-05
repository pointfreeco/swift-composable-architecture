import Dispatch

func mainActorNow<R: Sendable>(execute block: @MainActor @Sendable () -> R) -> R {
  if DispatchQueue.getSpecific(key: key) == value {
    return MainActor._assumeIsolated {
      block()
    }
  } else {
    return DispatchQueue.main.sync {
      MainActor._assumeIsolated {
        block()
      }
    }
  }
}

func mainActorASAP(execute block: @escaping @MainActor @Sendable () -> Void) {
  if DispatchQueue.getSpecific(key: key) == value {
    MainActor._assumeIsolated {
      block()
    }
  } else {
    DispatchQueue.main.async {
      MainActor._assumeIsolated {
        block()
      }
    }
  }
}

private let key: DispatchSpecificKey<UInt8> = {
  let key = DispatchSpecificKey<UInt8>()
  DispatchQueue.main.setSpecific(key: key, value: value)
  return key
}()
private let value: UInt8 = 0
