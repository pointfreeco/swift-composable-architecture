import Dispatch

func mainActorNow(execute block: @MainActor @Sendable () -> Void) {
  if DispatchQueue.getSpecific(key: key) == value {
    MainActor._assumeIsolated {
      block()
    }
  } else {
    DispatchQueue.main.sync {
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
