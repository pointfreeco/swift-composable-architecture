import Foundation

struct BenchmarkStudyConfiguration<Parameter> {
  init(cases: BenchmarkConfiguration = .init(), parameters: @escaping () -> [Parameter]) {
    self.cases = cases
    self.parameters = parameters
  }

  var cases: BenchmarkConfiguration = .init()
  var parameters: () -> [Parameter]
}

extension BenchmarkStudyConfiguration where Parameter == Void {
  init(_ cases: BenchmarkConfiguration = .init()) {
    self.cases = cases
    parameters = { [()] } // Nice!
  }
}

public struct BenchmarkConfiguration {
  public init(
    iterationsCount: ClosedRange<UInt> = 10 ... 1_000_000,
    maxDuration: TimeInterval = 5,
    warmupIterations: Int = 0
  ) {
    self.iterationsCount = iterationsCount
    self.maxDuration = maxDuration
    self.warmupIterations = warmupIterations
  }

  public var iterationsCount: ClosedRange<UInt>
  public var maxDuration: TimeInterval
  public var warmupIterations: Int

  var minIterations: Int { Int(iterationsCount.lowerBound) }
  var maxIterations: Int { Int(iterationsCount.upperBound) }
}

public struct ParametricBenchmarkStudy<Parameter> {
  var name: String

  var baseline: ParametricBenchmarkCase<Parameter>? = nil
  var cases: [ParametricBenchmarkCase<Parameter>] = []
  var configuration: BenchmarkStudyConfiguration<Parameter>

  func execute() -> Report {
    var baselineReports = [ParametricBenchmarkCase<Parameter>.Report]()
    var caseReports = [String: [ParametricBenchmarkCase<Parameter>.Report]]()
    for parameter in configuration.parameters() {
      if let baseline = baseline {
        let timestamp = timestampInNanoseconds()
        print("    Running \(baseline.label)…")
        let baselineReport = baseline.execute(with: configuration.cases, parameter: parameter)
        baselineReports.append(baselineReport)
        print("    Done! (\(TimeUnit.format(seconds(t1: timestamp, t2: timestampInNanoseconds()))))")
      }

      for benchmark in cases {
        let timestamp = timestampInNanoseconds()
        print("    Running \(benchmark.label)…")
        caseReports[benchmark.label, default: []]
          .append(benchmark.execute(with: configuration.cases, parameter: parameter))
        print("    Done! (\(TimeUnit.format(seconds(t1: timestamp, t2: timestampInNanoseconds()))))")
      }
    }

    return Report(name: name, baselines: baselineReports, cases: caseReports)
  }
}

public typealias BenchmarkStudy = ParametricBenchmarkStudy<Void>
public extension ParametricBenchmarkStudy where Parameter == Void {
  mutating func setBaseline(_ label: String = "Baseline", block: @escaping (_ measure: (MeasureDelimiter) -> Void) -> Void) {
    baseline = BenchmarkCase(label: label, block: .init(block: block))
  }

  mutating func addCase(_ label: String, block: @escaping (_ measure: (MeasureDelimiter) -> Void) -> Void) {
    cases.append(BenchmarkCase(label: label, block: .init(block: block)))
  }
}

extension ParametricBenchmarkStudy {
  struct Report {
    let name: String
    let baselines: [ParametricBenchmarkCase<Parameter>.Report]
    let cases: [String: [ParametricBenchmarkCase<Parameter>.Report]]

    func lines() -> [[Columns: String]] {
      let values = baselines.map(\.mean) + cases.values.flatMap { $0.map(\.mean) }
      guard let minValue = values.min() else { return [] }
      let timeUnit = TimeUnit.bestUnit(minValue)

      var lines: [[Columns: String]] = []
      let numberOfCases = 1 + cases.count
      var bestMean: TimeInterval = 0
      // TODO: Handle parametric case
      if let baseline = baselines.first {
        bestMean = baseline.mean
        for report in cases {
          bestMean = min(bestMean, report.value.first!.mean)
        }
        let componentsForBaseline: [Columns: String] = [
          .label: baseline.label,
          .best: formatIsBest(bestMean: bestMean, mean: baseline.mean, numberOfCases: numberOfCases),
          .mean: formatMeanTime(baseline.mean, unit: timeUnit),
          .delta: "",
          .variation: "",
          .performance: "",
          .standardError: formatStandardError(mean: baseline.mean, std: baseline.std),
          .iterations: formatIterations(baseline.iterations),
        ]
        lines.append(componentsForBaseline)
      }

      for (_, reports) in cases.sorted(by: { $0.key < $1.key }) {
        // TODO: Handle parametric case
        guard let report = reports.first else { continue }
        if let baseline = baselines.first {
          let delta = report.mean - baseline.mean
          let components: [Columns: String] = [
            .label: report.label,
            .best: formatIsBest(bestMean: bestMean, mean: report.mean, numberOfCases: numberOfCases),
            .mean: formatMeanTime(report.mean, unit: timeUnit),
            .delta: formatDeltaTime(delta, unit: timeUnit),
            .variation: formatVariation(baseline.mean, delta: delta),
            .performance: formatPerformance(baseline.mean, reportMean: report.mean),
            .standardError: formatStandardError(mean: report.mean, std: report.std),
            .iterations: formatIterations(report.iterations),
          ]
          lines.append(components)
        } else {
          // No baseline
          let components: [Columns: String] = [
            .label: report.label,
            .best: formatIsBest(bestMean: bestMean, mean: report.mean, numberOfCases: numberOfCases),
            .mean: formatMeanTime(report.mean, unit: timeUnit),
            .delta: "",
            .variation: "",
            .performance: "",
            .standardError: formatStandardError(mean: report.mean, std: report.std),
            .iterations: formatIterations(report.iterations),
          ]
          lines.append(components)
        }
      }
      return lines
    }

    func formatIterations(_ iterations: Int) -> String {
      String(format: "%d", iterations)
    }

    func formatMeanTime(_ mean: TimeInterval, unit: TimeUnit) -> String {
      unit.format(mean)
    }

    func formatDeltaTime(_ delta: TimeInterval, unit: TimeUnit) -> String {
      unit.format(delta, signed: true)
    }

    func formatVariation(_ baselineMean: TimeInterval, delta: TimeInterval) -> String {
      String(format: "%+.2f %%", 100 * delta / baselineMean)
    }

    func formatPerformance(_ baselineMean: TimeInterval, reportMean: TimeInterval) -> String {
      String(format: "x%.2f", baselineMean / reportMean)
    }

    func formatStandardError(mean: TimeInterval, std: TimeInterval) -> String {
      String(format: "±%.2f %%", 100 * std / mean)
    }

    func formatIsBest(bestMean: TimeInterval, mean: TimeInterval, numberOfCases: Int) -> String {
      if bestMean == mean, numberOfCases > 1 { return "(*)" }
      return ""
    }
  }
}

// MARK: - AnyBenchmarkStudy

struct AnyBenchmarkStudy {
  let name: String
  let execute: () -> [[Columns: String]]
  init<Parameter>(_ study: ParametricBenchmarkStudy<Parameter>) {
    name = study.name
    execute = {
      study
        .execute()
        .lines()
    }
  }
}

extension ParametricBenchmarkStudy {
  var erased: AnyBenchmarkStudy { AnyBenchmarkStudy(self) }
}
