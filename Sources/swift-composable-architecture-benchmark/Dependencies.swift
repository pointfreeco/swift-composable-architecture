import Benchmark
import Combine
import ComposableArchitecture
import Dependencies
import Foundation

let dependenciesSuite = BenchmarkSuite(name: "Dependencies") { suite in
  #if swift(>=5.7)
    let reducer: some ReducerProtocol<Int, Void> = EmptyReducer()
      .dependency(\.calendar, .autoupdatingCurrent)
      .dependency(\.date, .live)
      .dependency(\.locale, .autoupdatingCurrent)
      .dependency(\.mainQueue, .immediate)
      .dependency(\.mainRunLoop, .immediate)
      .dependency(\.timeZone, .autoupdatingCurrent)
      .dependency(\.uuid, .live)

    suite.benchmark("Dependency key writing") {
      var state = 0
      _ = reducer.reduce(into: &state, action: ())
      precondition(state == 0)
    }
  #endif
}
