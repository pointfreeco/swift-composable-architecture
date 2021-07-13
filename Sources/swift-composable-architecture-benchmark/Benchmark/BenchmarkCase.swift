import Foundation

public struct ParametricBenchmarkCase<Parameter> {
  init(label: String, block: ParametricBenchmarkBlock<Parameter>) {
    self.label = label
    self.block = block
  }

  let label: String
  let block: ParametricBenchmarkBlock<Parameter>

  func execute(with configuration: BenchmarkConfiguration = .init(), parameter: Parameter) -> Report {
    var durations = [TimeInterval]()
    let start = timestampInNanoseconds()
    var iterations = -configuration.warmupIterations
    while iterations < configuration.maxIterations {
      let measure = block.execute(parameter: parameter)
      if iterations >= 0 {
        durations.append(measure)
      }
      iterations += 1

      if seconds(t1: start, t2: timestampInNanoseconds()) > configuration.maxDuration,
         iterations >= configuration.minIterations
      {
        break
      }
    }

    return Report(label: label, parameter: parameter, configuration: configuration, durations: durations)
  }
}

public typealias BenchmarkCase = ParametricBenchmarkCase<Void>

extension ParametricBenchmarkCase where Parameter == Void {
  init(label: String, block: BenchmarkBlock) {
    self.label = label
    self.block = block
  }
}

extension ParametricBenchmarkCase {
  struct Report {
    init(
      label: String,
      parameter: Parameter,
      configuration: BenchmarkConfiguration,
      durations: [TimeInterval]
    ) {
      self.label = label
      self.parameter = parameter
      self.configuration = configuration
      self.durations = durations
      iterations = durations.count
      let (mean, stdDev) = durations.meanAndStandardDeviation ?? (0, 0)
      self.mean = mean
      std = stdDev / sqrt(Double(iterations))
    }

    let label: String
    let parameter: Parameter
    let configuration: BenchmarkConfiguration
    let durations: [TimeInterval]

    let iterations: Int
    let mean: Double
    let std: Double
  }
}
