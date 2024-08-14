import Dispatch

func mainActorASAP(execute block: @escaping @MainActor @Sendable () -> Void) {
  if DispatchQueue.getSpecific(key: key.wrappedValue) == value {
    MainActor._assumeIsolated {
      block()
    }
  } else {
    DispatchQueue.main.async {
      block()
    }
  }
}

func mainActorNow<T: Sendable>(execute block: @escaping @MainActor @Sendable () -> T) -> T {
  if DispatchQueue.getSpecific(key: key.wrappedValue) == value {
    return MainActor._assumeIsolated {
      block()
    }
  } else {
    return DispatchQueue.main.sync {
      MainActor._assumeIsolated { block() }
    }
  }
}

private let key: UncheckedSendable<DispatchSpecificKey<UInt8>> = {
  let key = DispatchSpecificKey<UInt8>()
  DispatchQueue.main.setSpecific(key: key, value: value)
  return UncheckedSendable(key)
}()
private let value: UInt8 = 0
