import Foundation

public struct BenchmarkSuite {
  public let name: String
  var studies: [AnyBenchmarkStudy] = []

  internal init(name: String, studies: [AnyBenchmarkStudy] = []) {
    self.name = name
    self.studies = studies
  }

  public init(_ name: String, block: (inout BenchmarkSuite) -> Void) {
    var suite = BenchmarkSuite(name: name)
    block(&suite)
    self = suite
  }

  public mutating func addStudy(_ name: String,
                                configuration: BenchmarkConfiguration = .init(),
                                block: (inout BenchmarkStudy) -> Void)
  {
    var study = BenchmarkStudy(name: name, configuration: .init(configuration))
    block(&study)
    studies.append(study.erased)
  }

  func execute() -> Report {
    var reports = [String: [[Columns: String]]]()
    print("Running \(name)…")
    for study in studies {
      let timestamp = timestampInNanoseconds()
      print("  Running \(study.name)…")
      reports[study.name] = study.execute()
      print("  Done! (\(TimeUnit.format(seconds(t1: timestamp, t2: timestampInNanoseconds()))))")
    }
    print("Done!")
    return Report(name: name, studiesReports: reports)
  }
}

extension BenchmarkSuite {
  struct Report {
    let name: String
    let studiesReports: [String: [[Columns: String]]]

    func formattedString() -> String {
      guard !studiesReports.isEmpty else { return "" }
      let header = Dictionary(uniqueKeysWithValues:
        Columns.allCases.map { ($0, $0.title) })

      let maxWidthPerColumns = studiesReports
        .values
        .flatMap { $0 }
        .reduce(header.mapValues(\.count)) {
          $0.merging($1.mapValues(\.count), uniquingKeysWith: max)
        }

      let length = maxWidthPerColumns.values.reduce(0, +) + (maxWidthPerColumns.count - 1)

      var output = [String]()

      func write(label: String, indent: Int, char: String) {
        let prefix = String(repeating: char, count: indent)
        let suffixLength = max(0, length - label.count - indent)
        let suffix = String(repeating: char, count: suffixLength)
        output.append("\(prefix)\(label)\(suffix)")
      }

      func write(line: [Columns: String]) {
        var lineComponents: [String] = []
        for column in Columns.allCases {
          lineComponents.append(
            align(string: line[column, default: ""],
                  length: maxWidthPerColumns[column],
                  alignment: column == .label ? .left : .right)
          )
        }
        output.append(lineComponents.joined(separator: " "))
      }

      write(label: " \(name) ", indent: 2, char: "=")
      write(line: header)

      var previousHadMultipleCases: Bool = false
      for (reportName, report) in studiesReports.sorted(by: { $0.key < $1.key }) {
        if report.count > 1 {
          write(label: " \(reportName) ", indent: 2, char: "-")
        } else if previousHadMultipleCases {
          write(label: "", indent: 0, char: "-")
        }
        report.forEach(write(line:))
        previousHadMultipleCases = report.count > 1
      }
      output.append(String(repeating: "=", count: length))

      return output.joined(separator: "\n") + "\n"
    }

    enum Alignment {
      case left
      case right
      case center
    }

    func align(string: String, length: Int?, alignment: Alignment = .right) -> String {
      guard let length = length else { return string }
      guard string.count <= length else { return String(string.prefix(length)) }
      let padding = String(repeating: " ", count: length - string.count)
      switch alignment {
      case .left:
        return string + padding
      case .right:
        return padding + string
      case .center:
        let padding = String(repeating: " ", count: (length - string.count) / 2)
        return padding + string + padding + ((length - string.count).isMultiple(of: 2) ? "" : " ")
      }
    }
  }
}

@discardableResult
public func benchmarkSuite(_ name: String, block: (inout BenchmarkSuite) -> Void) -> BenchmarkSuite {
  let suite = BenchmarkSuite(name, block: block)
  Benchmark.suites.append(suite)
  return suite
}
