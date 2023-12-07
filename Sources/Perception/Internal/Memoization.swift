import Foundation
import OrderedCollections

final class MemoizedCache<Key: Hashable, Value>: @unchecked Sendable {
  private var dictionary = OrderedDictionary<Key, Value>()
  private var lock = NSLock()
  private let maxCapacity: Int
  
  // TODO possibly remove these stats later
  private var totalEvictions = 0
  private var totalCalls = 0
  private var totalHits = 0
  
  init(maxCapacity: Int = 500) {
    self.maxCapacity = maxCapacity
  }
  
  func printStats() {
    lock.sync {
      let hitRate = (Float(totalHits) / Float(totalCalls)) * 100
      let evictionRate = (Float(totalEvictions) / Float(totalCalls)) * 100
      print("size = \(dictionary.count), totalCalls = \(totalCalls), hitRate = \(hitRate)%, evictionRate = \(evictionRate)%")
    }
  }
  
  subscript(key: Key) -> Value? {
    get {
      lock.sync {
        totalCalls += 1
        if let value = dictionary[key] {
          totalHits += 1
          return value
        }
        return nil
      }
    }
    set {
      lock.sync {
        dictionary[key] = newValue
        if dictionary.count > maxCapacity {
          // evict first (oldest) element
          dictionary.removeFirst()
          totalEvictions += 1
        }
      }
    }
  }
  
}

func memoize<Input: Hashable, Result>(
  maxCapacity: Int = 500,
  _ apply: @escaping (_ key: Input) -> Result
) -> (Input) -> Result {
  let cache = MemoizedCache<Input, Result>(maxCapacity: maxCapacity)
  
  return { input in
    //    defer {
    //       cache.printStats()
    //    }
    if let memoizedResult = cache[input] {
      return memoizedResult
    }
    
    let result = apply(input)
    cache[input] = result
    return result
  }
  
}
