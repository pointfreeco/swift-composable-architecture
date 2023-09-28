import OSLog

@_spi(Logging)
public final class Logger {
  public static let shared = Logger()
  @Published public var logs: [String] = []
  #if DEBUG
    @available(iOS 14.0, *)
    var logger: os.Logger {
      os.Logger(subsystem: "composable-architecture", category: "store-events")
    }
    public func log(level: OSLogType = .default, _ string: @autoclosure () -> String) {
      let string = string()
      if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
        print("\(string)")
      } else {
        if #available(iOS 14.0, *) {
          self.logger.log(level: level, "\(string)")
        }
      }
      self.logs.append(string)
    }
    public func clear() {
      self.logs = []
    }
  #else
    @inlinable @inline(__always)
    public func log(level: OSLogType = .default, _ string: @autoclosure () -> String) {
    }
    @inlinable @inline(__always)
    public func clear() {
    }
  #endif
}
