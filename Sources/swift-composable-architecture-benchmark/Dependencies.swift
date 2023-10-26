import Benchmark
import Combine
import ComposableArchitecture
import Dependencies
import Foundation

let dependenciesSuite = BenchmarkSuite(name: "Dependencies") { suite in
  let reducer: some Reducer<Int, Void> = BenchmarkReducer()
    .dependency(\.calendar, .autoupdatingCurrent)
    .dependency(\.date, .init { Date() })
    .dependency(\.locale, .autoupdatingCurrent)
    .dependency(\.mainQueue, .immediate)
    .dependency(\.mainRunLoop, .immediate)
    .dependency(\.timeZone, .autoupdatingCurrent)
    .dependency(\.uuid, .init { UUID() })

  suite.benchmark("Dependency key writing") {
    var state = 0
    _ = reducer.reduce(into: &state, action: ())
    precondition(state == 1)
  }
}

@Reducer
private struct BenchmarkReducer {
  @Dependency(\.someValue) var someValue
  var body: some Reducer<Int, Void> {
    Reduce { state, action in
      state = self.someValue
      return .none
    }
  }
}
private enum SomeValueKey: DependencyKey {
  static let liveValue = 1
}
extension DependencyValues {
  var someValue: Int {
    self[SomeValueKey.self]
  }
}
