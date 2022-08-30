import Benchmark
import Combine
import ComposableArchitecture
import Foundation

let effectSuite = BenchmarkSuite(name: "Effects") {
  $0.benchmark("Merged Effect.none (create, flat)") {
    let effect = Effect<Int, Never>.merge((1...100).map { _ in .none })
  }

  $0.benchmark("Merged Effect.none (create, nested)") {
    var effect = Effect<Int, Never>.none
    for _ in 1...100 {
      effect = .merge(effect, .none)
    }
  }

  var effect = Effect<Int, Never>.none
  for _ in 1...100 {
    effect = .merge(effect, .none)
  }
  $0.benchmark("Merged Effect.none (sink)") {
    _ = effect.sink(receiveCompletion: { _ in }, receiveValue: { _ in })
  }
}
