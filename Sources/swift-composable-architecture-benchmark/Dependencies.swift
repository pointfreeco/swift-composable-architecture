import Benchmark
import Combine
import ComposableArchitecture
import Dependencies
import Foundation

let dependenciesSuite = BenchmarkSuite(name: "Dependencies") { suite in
  #if swift(>=5.7)
    let reducer: some ReducerProtocol<Int, Void> = BenchmarkReducer()
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
  #endif
}

private struct BenchmarkReducer: ReducerProtocol {
  @Dependency(\.someValue) var someValue
  func reduce(into state: inout Int, action: Void) -> Effect<Void, Never> {
    state = self.someValue
    return .none
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
