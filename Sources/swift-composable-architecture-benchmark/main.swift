import Benchmark
import ComposableArchitecture

Benchmark.main([
  defaultBenchmarkSuite,
  dependenciesSuite,
  effectSuite,
  storeScopeSuite,
  viewStoreSuite,
])
