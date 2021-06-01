/// Raises a debug breakpoint iff a debugger is attached.
@inline(__always) func breakpoint() {
  #if DEBUG
  // https://github.com/bitstadium/HockeySDK-iOS/blob/c6e8d1e940299bec0c0585b1f7b86baf3b17fc82/Classes/BITHockeyHelper.m#L346-L370
  var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
  var info: kinfo_proc = kinfo_proc()
  var info_size = MemoryLayout<kinfo_proc>.size

  let isDebuggerAttached = name.withUnsafeMutableBytes {
    $0.bindMemory(to: Int32.self).baseAddress
      .map { sysctl($0, 4, &info, &info_size, nil, 0) != -1 && info.kp_proc.p_flag & P_TRACED != 0 }
      ?? false
  }

  if isDebuggerAttached {
    fputs(
      """
      Caught debug breakpoint. Type "continue" ("c") to resume execution.

      """,
      stderr
    )
    raise(SIGTRAP)
  }
  #endif
}
