import Benchmark
import ComposableArchitecture

let effectsSuite = BenchmarkSuite(name: "Effects") { suite in

  suite.benchmark(".merge([a, b])") {
    _ = Effect<Void, Never>.merge([.none, .none]).sink {}
  }

  suite.benchmark(".merge(a, b)") {
    _ = Effect<Void, Never>.merge(.none, .none).sink {}
  }

  suite.benchmark(".merge([a, b, c, d, e, f, g, h])") {
    _ = Effect<Void, Never>.merge([.none, .none, .none, .none, .none, .none, .none, .none]).sink {}
  }

  suite.benchmark(".merge(a, b, c, d, e, f, g, h)") {
    _ = Effect<Void, Never>.merge(.none, .none, .none, .none, .none, .none, .none, .none).sink {}
  }
}
