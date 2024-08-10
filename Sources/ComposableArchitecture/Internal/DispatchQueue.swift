import Dispatch

func mainActorASAP(execute block: @escaping @MainActor @Sendable () -> Void) {
  if DispatchQueue.getSpecific(key: key) == value {
    assumeMainActorIsolated {
      block()
    }
  } else {
    DispatchQueue.main.async {
      block()
    }
  }
}

func mainActorNow(execute block: @escaping @MainActor @Sendable () -> Void) {
  if DispatchQueue.getSpecific(key: key) == value {
    assumeMainActorIsolated {
      block()
    }
  } else {
    DispatchQueue.main.sync {
      block()
    }
  }
}

private let key: DispatchSpecificKey<UInt8> = {
  let key = DispatchSpecificKey<UInt8>()
  DispatchQueue.main.setSpecific(key: key, value: value)
  return key
}()
private let value: UInt8 = 0

// NB: Currently we can't use 'MainActor.assumeIsolated' on CI, but we can approximate this in
//     the meantime.
#if swift(<5.10)
  @MainActor(unsafe)
#else
  @preconcurrency @MainActor
#endif
private func assumeMainActorIsolated(_ block: @escaping @MainActor @Sendable () -> Void) {
  block()
}
