import Foundation

public func benchmark(_ label: String, block: @escaping () -> Void) {
  let benchmark = BenchmarkCase(label: label,
                                block: BenchmarkBlock(block: { _ in block() }))
  let study = BenchmarkStudy(name: label, baseline: benchmark, cases: [], configuration: .init())
  defaultBenchmarkSuite.studies.append(study.erased)
}

public var defaultBenchmarkSuite = BenchmarkSuite(name: "Default Suite", studies: [])

public extension BenchmarkSuite {
  mutating func benchmark(_ label: String, block: @escaping () -> Void) {
    let benchmark = BenchmarkCase(label: label,
                                  block: BenchmarkBlock(block: { _ in block() }))
    let study = BenchmarkStudy(name: label, baseline: benchmark, cases: [], configuration: .init())
    studies.append(study.erased)
  }
}

public extension BenchmarkSuite {
  mutating func register(benchmark: AnyBenchmark) {
    let benchmarkCase = BenchmarkCase(label: benchmark.name, block: .init(block: { measure in
      benchmark.setUp()
      var state = BenchmarkState()
      measure(.start)
      try! benchmark.run(&state)
      measure(.stop)
      benchmark.tearDown()

    }))
    studies.append(
      BenchmarkStudy(name: benchmark.name, baseline: benchmarkCase, cases: [], configuration: .init()).erased
    )
  }
}

public struct BenchmarkSetting {}
public struct BenchmarkState {}
public protocol AnyBenchmark {
  var name: String { get }
  var settings: [BenchmarkSetting] { get }
  func setUp()
  func run(_ state: inout BenchmarkState) throws
  func tearDown()
}
