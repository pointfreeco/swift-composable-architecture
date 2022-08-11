import Benchmark
import ComposableArchitecture

let counterReducer = Reducer<Int, Bool, Void> { state, action, _ in
  if action {
    state += 1
  } else {
    state = 0
  }
  return .none
}

let store1 = Store(initialState: 0, reducer: counterReducer, environment: ())
let store2 = store1.scope { $0 }
let store3 = store2.scope { $0 }
let store4 = store3.scope { $0 }

let viewStore1 = ViewStore(store1)
let viewStore2 = ViewStore(store2)
let viewStore3 = ViewStore(store3)
let viewStore4 = ViewStore(store4)

//benchmark("Scoping (1)") {
//  viewStore1.send(true)
//}
//viewStore1.send(false)
//
//benchmark("Scoping (2)") {
//  viewStore2.send(true)
//}
//viewStore1.send(false)
//
//benchmark("Scoping (3)") {
//  viewStore3.send(true)
//}
//viewStore1.send(false)
//
//benchmark("Scoping (4)") {
//  viewStore4.send(true)
//}

enum Globals {
  static var value = 42
}

enum Locals {
  @TaskLocal static var value = 42
}

benchmark("Locals.value") {
  precondition(Locals.value == 42)
}
benchmark("Globals.value") {
  precondition(Globals.value == 42)
}
benchmark("Locals.$value.withValue") {
  Locals.$value.withValue(1729) {
    precondition(Locals.value == 1729)
  }
}
benchmark("Globals.value mutate") {
  Globals.value = 1729
  precondition(Globals.value == 1729)
}
benchmark("Locals.$value.withValue × 2") {
  Locals.$value.withValue(1729) {
    Locals.$value.withValue(42) {
      precondition(Locals.value == 42)
    }
  }
}
benchmark("Globals.value mutate × 2") {
  Globals.value = 1729
  Globals.value = 42
  precondition(Globals.value == 42)
}
benchmark("Locals.$value.withValue × 3") {
  Locals.$value.withValue(1729) {
    Locals.$value.withValue(42) {
      Locals.$value.withValue(1729) {
        precondition(Locals.value == 1729)
      }
    }
  }
}
benchmark("Globals.value mutate × 3") {
  Globals.value = 1729
  Globals.value = 42
  Globals.value = 1729
  precondition(Globals.value == 1729)
}
benchmark("Locals.$value.withValue × 4") {
  Locals.$value.withValue(1729) {
    Locals.$value.withValue(42) {
      Locals.$value.withValue(1729) {
        Locals.$value.withValue(42) {
          precondition(Locals.value == 42)
        }
      }
    }
  }
}
benchmark("Globals.value mutate × 4") {
  Globals.value = 1729
  Globals.value = 42
  Globals.value = 1729
  Globals.value = 42
  precondition(Globals.value == 42)
}

Benchmark.main()
