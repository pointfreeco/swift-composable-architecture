import Benchmark
import ComposableArchitecture

Benchmark.main(
  [
    basicStoreScopeSuite,
    effectsSuite,
    reducerSuite,
  ]
)
