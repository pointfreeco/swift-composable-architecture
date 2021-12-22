final class WeakCache<Key, Value> where Key: Hashable, Value: AnyObject {
  init() {}
  
  private struct WeakObject {
    weak var value: Value?
    init(_ value: Value) {
      self.value = value
    }
  }

  private var maintenanceCounter: Int = 0
  private var wrappers: [Key: WeakObject] = [:]
    
  subscript(key: Key) -> Value? {
    get {
      defer { performMaintenanceIfNeeded() }
      if let weakWrapper = wrappers[key] {
        if let value = weakWrapper.value {
          return value
        } else {
          wrappers[key] = nil
        }
      }
      return nil
    }
    
    set {
      defer { performMaintenanceIfNeeded() }
      if let newValue = newValue {
        wrappers[key] = .init(newValue)
      } else {
        wrappers[key] = nil
      }
      performMaintenanceIfNeeded()
    }
  }
  
  func performMaintenanceIfNeeded() {
    maintenanceCounter += 1
    if maintenanceCounter >= 100 {
      wrappers = wrappers.filter { $0.value.value != nil }
      maintenanceCounter = 0
    }
  }
}
