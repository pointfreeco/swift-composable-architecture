import Benchmark
import Combine
import ComposableArchitecture
import Foundation

let effectSuite = BenchmarkSuite(name: "Effects") {
  $0.benchmark("Merging Effect.none") {
    var effect = Effect<Int, Never>.none
    for _ in 1...1_000 {
      effect = .merge(effect, .none)
    }
    _ = effect.sink(receiveCompletion: { _ in }, receiveValue: { _ in })
  }
}
