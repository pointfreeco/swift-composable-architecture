#if DEBUG
  import Foundation
  import OrderedCollections

  func memoize<Result>(
    maxCapacity: Int = 500,
    _ apply: @escaping () -> Result
  ) -> () -> Result {
    let cache = Cache<[NSNumber], Result>(maxCapacity: maxCapacity)
    return {
      let callStack = Thread.callStackReturnAddresses
      guard let memoizedResult = cache[callStack]
      else {
        let result = apply()
        defer { cache[callStack] = result }
        return result
      }
      return memoizedResult
    }
  }

  private final class Cache<Key: Hashable, Value>: @unchecked Sendable {
    var dictionary = OrderedDictionary<Key, Value>()
    var lock = NSLock()
    let maxCapacity: Int
    init(maxCapacity: Int = 500) {
      self.maxCapacity = maxCapacity
    }
    subscript(key: Key) -> Value? {
      get {
        self.lock.sync {
          self.dictionary[key]
        }
      }
      set {
        self.lock.sync {
          self.dictionary[key] = newValue
          if self.dictionary.count > self.maxCapacity {
            self.dictionary.removeFirst()
          }
        }
      }
    }
  }
#endif
