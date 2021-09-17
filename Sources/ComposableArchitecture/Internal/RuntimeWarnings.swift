import OSLog

#if DEBUG
  let rwDso: UnsafeMutableRawPointer = {
    var info = Dl_info()
    dladdr(dlsym(dlopen(nil, RTLD_LAZY), "$s7SwiftUI4TextV8verbatimACSS_tcfC"), &info)
    return info.dli_fbase
  }()
  let rwLog = OSLog(subsystem: "com.apple.runtime-issues", category: "ComposableArchitecture")
#endif
