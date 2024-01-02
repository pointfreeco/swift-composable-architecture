import Benchmark
import ComposableArchitecture

Benchmark.main([
  defaultBenchmarkSuite,
  dependenciesSuite,
  effectSuite,
  observationSuite,
  storeScopeSuite,
  storeSuite,
  viewStoreSuite,
])
