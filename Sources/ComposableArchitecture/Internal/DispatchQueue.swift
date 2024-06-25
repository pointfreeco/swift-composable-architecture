import Dispatch

func mainActorASAP(execute block: @escaping @MainActor @Sendable () -> Void) {
  if DispatchQueue.getSpecific(key: key) == value {
    MainActor.assumeIsolated {
      block()
    }
  } else {
    DispatchQueue.main.async {
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
