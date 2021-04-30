import Benchmark

extension BenchmarkSuite {
  func benchmark(
    name: String,
    setUp: @escaping () -> Void = {},
    run: @escaping () throws -> Void,
    tearDown: @escaping () -> Void = {}
  ) {
    self.register(
      benchmark: Benchmarking(name: name, run: run, setUp: setUp, tearDown: tearDown)
    )
  }
}

struct Benchmarking: AnyBenchmark {
  let name: String
  let settings: [BenchmarkSetting] = []
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
