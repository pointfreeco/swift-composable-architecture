import Foundation

#if canImport(AppKit)
  import AppKit
#endif
#if canImport(UIKit)
  import UIKit
#endif
#if canImport(WatchKit)
  import WatchKit
#endif

@_spi(Internals)
public var willResignNotificationName: Notification.Name? {
  #if os(iOS) || os(tvOS) || os(visionOS)
    return UIApplication.willResignActiveNotification
  #elseif os(macOS)
    return NSApplication.willResignActiveNotification
  #else
    if #available(watchOS 7, *) {
      return WKExtension.applicationWillResignActiveNotification
    } else {
      return nil
    }
  #endif
}

@_spi(Internals)
public let willEnterForegroundNotificationName: Notification.Name? = {
  #if os(iOS) || os(tvOS) || os(visionOS)
    return UIApplication.willEnterForegroundNotification
  #elseif os(macOS)
    return NSApplication.willBecomeActiveNotification
  #else
    if #available(watchOS 7, *) {
      return WKExtension.applicationWillEnterForegroundNotification
    } else {
      return nil
    }
  #endif
}()

@_spi(Internals)
public let willTerminateNotificationName: Notification.Name? = {
  #if os(iOS) || os(tvOS) || os(visionOS)
    return UIApplication.willTerminateNotification
  #elseif os(macOS)
    return NSApplication.willTerminateNotification
  #else
    return nil
  #endif
}()

var canListenForResignActive: Bool {
  willResignNotificationName != nil
}
