import CollectionsBenchmark
import ComposableArchitecture
import OrderedCollections

extension Int: Identifiable { public var id: Int { self } }

var benchmark = Benchmark(title: "Identified Benchmark")

//benchmark.add(
//  title: "Array<Int> removeAll",
//  input: Int.self
//) { size in
//  return { timer in
//    var array = Array(0 ..< size)
//    array.insert(-1, at: .random(in: 0..<array.count))
//    timer.measure {
//      array.removeAll(where: { $0 == -1 })
//    }
//    blackHole(array)
//  }
//}
//
//benchmark.add(
//  title: "OrderedSet<Int> remove",
//  input: Int.self
//) { size in
//  return { timer in
//    var set = OrderedSet(0 ..< size)
//    set.insert(-1, at: .random(in: 0..<set.count))
//    timer.measure {
//      set.remove(-1)
//    }
//    blackHole(set)
//  }
//}
//
//benchmark.add(
//  title: "IdentifiedArray<Int, Int> remove",
//  input: Int.self
//) { size in
//  return { timer in
//    var array = IdentifiedArray(0 ..< size)
//    array.insert(-1, at: .random(in: 0..<array.count))
//    timer.measure {
//      array.remove(id: -1)
//    }
//    blackHole(array)
//  }
//}
//
//benchmark.add(
//  title: "IdentifiedArray<Int> remove",
//  input: Int.self
//) { size in
//  return { timer in
//    var array = _IdentifiedArray(0 ..< size)
//    array.insert(-1, at: .random(in: 0..<array.count))
//    timer.measure {
//      array.remove(id: -1)
//    }
//    blackHole(array)
//  }
//}

//benchmark.add(
//  title: "Array<Int> removeFirst",
//  input: Int.self
//) { size in
//  return { timer in
//    var array = Array(0 ..< size)
//    timer.measure {
//      for _ in 0 ..< size {
//        array.removeFirst()
//      }
//    }
//    precondition(array.isEmpty)
//    blackHole(array)
//  }
//}
//
//benchmark.add(
//  title: "OrderedSet<Int> removeFirst",
//  input: Int.self
//) { size in
//  return { timer in
//    var set = OrderedSet(0 ..< size)
//    timer.measure {
//      for _ in 0 ..< size {
//        set.removeFirst()
//      }
//    }
//    precondition(set.isEmpty)
//    blackHole(set)
//  }
//}
//
//benchmark.add(
//  title: "IdentifiedArray<Int, Int> removeFirst",
//  input: Int.self
//) { size in
//  return { timer in
//    var array = IdentifiedArray(0 ..< size)
//    timer.measure {
//      for _ in 0 ..< size {
//        array.removeFirst()
//      }
//    }
//    precondition(array.isEmpty)
//    blackHole(array)
//  }
//}
//
//benchmark.add(
//  title: "IdentifiedArray<Int> removeFirst",
//  input: Int.self
//) { size in
//  return { timer in
//    var array = _IdentifiedArray(0 ..< size)
//    timer.measure {
//      for _ in 0 ..< size {
//        array.removeFirst()
//      }
//    }
//    precondition(array.isEmpty)
//    blackHole(array)
//  }
//}

benchmark.addSimple(
  title: "Array<Int> append",
  input: [Int].self
) { input in
  var array: [Int] = []
  for i in input {
    array.append(i)
  }
  precondition(array.count == input.count)
  blackHole(array)
}

benchmark.addSimple(
  title: "OrderedSet<Int> append",
  input: [Int].self
) { input in
  var set: OrderedSet<Int> = []
  for i in input {
    set.append(i)
  }
  precondition(set.count == input.count)
  blackHole(set)
}

benchmark.addSimple(
  title: "IdentifiedArray<Int, Int> append",
  input: [Int].self
) { input in
  var array: IdentifiedArray<Int, Int> = []
  for i in input {
    array.append(i)
  }
  precondition(array.count == input.count)
  blackHole(array)
}

benchmark.addSimple(
  title: "IdentifiedArray<Int> append",
  input: [Int].self
) { input in
  var array: _IdentifiedArray<Int, Int> = []
  for i in input {
    array.append(i)
  }
  precondition(array.count == input.count)
  blackHole(array)
}

benchmark.main()
