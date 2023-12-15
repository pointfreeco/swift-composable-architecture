import Benchmark
import ComposableArchitecture

if #available(macOS 14.0, *) {
  Benchmark.main([
    defaultBenchmarkSuite,
    dependenciesSuite,
    effectSuite,
    observationSuite,
    storeScopeSuite,
    storeSuite,
    viewStoreSuite,
  ])
} else {
  fatalError("Run on macOS 14 or higher.")
}
