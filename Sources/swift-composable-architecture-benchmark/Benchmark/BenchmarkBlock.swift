import Foundation

public enum MeasureDelimiter {
  case start
  case stop
}

public struct ParametricBenchmarkBlock<Parameter> {
  public init(block: @escaping (_ measure: (MeasureDelimiter) -> Void,
                                _ parameter: Parameter) -> Void)
  {
    self.block = block
  }

  let block: (_ measure: (MeasureDelimiter) -> Void, _ parameter: Parameter) -> Void

  func execute(parameter: Parameter) -> TimeInterval {
    var explicitStartTime: UInt64?
    var explicitEndTime: UInt64?
    let measure: (MeasureDelimiter) -> Void = {
      switch $0 {
      case .start:
        guard explicitStartTime == nil else {
          fatalError("`measure(.start)` was called more than once.")
        }
        explicitStartTime = timestampInNanoseconds()
      case .stop:
        guard explicitEndTime == nil else {
          fatalError("`measure(.stop)` was called more than once.")
        }
        explicitEndTime = timestampInNanoseconds()
      }
    }
    let implicitStartTime = timestampInNanoseconds()
    block(measure, parameter)
    let implicitEndTime = timestampInNanoseconds()

    let startTime = explicitStartTime ?? implicitStartTime
    let endTime = explicitEndTime ?? implicitEndTime

    return seconds(t1: startTime, t2: endTime)
  }
}

public typealias BenchmarkBlock = ParametricBenchmarkBlock<Void>
public extension BenchmarkBlock {
  init(block: @escaping (_ measure: (MeasureDelimiter) -> Void) -> Void) {
    self.block = { mesure, _ in block(mesure) }
  }
}
