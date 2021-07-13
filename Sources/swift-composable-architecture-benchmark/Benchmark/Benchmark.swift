import Foundation

public enum Benchmark {
  public static var suites: [BenchmarkSuite] = [defaultBenchmarkSuite]
  public static func main(_ suites: [BenchmarkSuite] = Self.suites) {
    var reports = String()
    for suite in suites {
      let report = suite.execute()
      reports.append(report.formattedString() + "\n")
    }
    print("Benchmark Results:")
    print(reports)
  }
}
