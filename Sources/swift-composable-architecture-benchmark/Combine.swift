import Benchmark
import ComposableArchitecture

let combine = BenchmarkSuite(name: "Combine") { suite in
  let count = 1

  suite.benchmark("Reducer: Single counter") {
    var state = 0
    for _ in 1...count {
      _ = counterReducer.run(&state, true, ())
    }
    precondition(state == count)
  }
  suite.benchmark("Protocol: Single counter") {
    var state = 0
    for _ in 1...count {
      _ = Counter().reduce(into: &state, action: true)
    }
    precondition(state == count)
  }
  suite.benchmark("Reducer: Ten counters") {
    var state = 0
    for _ in 1...count {
      _ = tenCountersReducer.run(&state, true, ())
    }
    precondition(state == 10 * count)
  }
  suite.benchmark("Protocol: Ten counters") {
    var state = 0
    for _ in 1...count {
      _ = TenCounters().reduce(into: &state, action: true)
    }
    precondition(state == 10 * count)
  }
  suite.benchmark("Reducer: Many counters") {
    var state = 0
    for _ in 1...count {
      _ = manyCountersReducer.run(&state, true, ())
    }
    precondition(state == 1000 * count)
  }
  suite.benchmark("Protocol: Many counters") {
    var state = 0
    for _ in 1...count {
      _ = ManyCounters().reduce(into: &state, action: true)
    }
    precondition(state == 1000 * count)
  }
}

private let counterReducer = Reducer<Int, Bool, Void> { state, action, _ in
  if action {
    state += 1
  } else {
    state = 0
  }
  return .none
}

private struct Counter: ReducerProtocol {
  func reduce(into state: inout Int, action: Bool) -> Effect<Bool, Never> {
    if action {
      state += 1
    } else {
      state = 0
    }
    return .none
  }
}

private let tenCountersReducer = Reducer.combine(
  counterReducer,
  counterReducer,
  counterReducer,
  counterReducer,
  counterReducer,
  counterReducer,
  counterReducer,
  counterReducer,
  counterReducer,
  counterReducer
)

private struct TenCounters: ReducerProtocol {
  var body: some ReducerProtocol<Int, Bool> {
    Counter()
    Counter()
    Counter()
    Counter()
    Counter()
    Counter()
    Counter()
    Counter()
    Counter()
    Counter()
  }
}

private let manyCountersReducer = Reducer<Int, Bool, Void>.combine(
  (1...1000).map { _ in counterReducer }
)

private struct ManyCounters: ReducerProtocol {

  var body: some ReducerProtocol<Int, Bool> {
    for _ in 1...1000 {
      Counter()
    }
  }
}
