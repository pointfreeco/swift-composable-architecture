import OSLog

@_spi(Logging)
public final class Logger {
  public static let shared = Logger()
  public var isEnabled = false
  @Published public var logs: [String] = []
  #if DEBUG
    @available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
    var logger: os.Logger {
      os.Logger(subsystem: "composable-architecture", category: "store-events")
    }
    public func log(level: OSLogType = .default, _ string: @autoclosure () -> String) {
      guard self.isEnabled else { return }
      let string = string()
      if isRunningForPreviews {
        print("\(string)")
      } else {
        if #available(iOS 14, macOS 11, tvOS 14, watchOS 7, *) {
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

private var isRunningForPreviews =
  ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
