import Benchmark

extension BenchmarkSuite {
  func benchmark(
    _ name: String,
    run: @escaping () throws -> Void,
    setUp: @escaping () -> Void = {},
    tearDown: @escaping () -> Void
  ) {
    self.register(
      benchmark: Benchmarking(name: name, run: run, setUp: setUp, tearDown: tearDown)
    )
  }
}

struct Benchmarking: AnyBenchmark {
  let name: String
  let settings: [any BenchmarkSetting] = []
  private let _run: () throws -> Void
  private let _setUp: () -> Void
  private let _tearDown: () -> Void

  init(
    name: String,
    run: @escaping () throws -> Void,
    setUp: @escaping () -> Void = {},
    tearDown: @escaping () -> Void = {}
  ) {
    self.name = name
    self._run = run
    self._setUp = setUp
    self._tearDown = tearDown
  }

  func setUp() {
    self._setUp()
  }

  func run(_ state: inout BenchmarkState) throws {
    try self._run()
  }

  func tearDown() {
    self._tearDown()
  }
}

@inline(__always)
func doNotOptimizeAway<T>(_ x: T) {
  @_optimize(none)
  func assumePointeeIsRead(_ x: UnsafeRawPointer) {}

  withUnsafePointer(to: x) { assumePointeeIsRead($0) }
}
