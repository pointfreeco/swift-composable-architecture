import Benchmark
import ComposableArchitecture

Benchmark.main([
  defaultBenchmarkSuite,
  
  bindingSuite,
  compositionSuite,
  scopingSuite,
  viewStoreSuite,
])
