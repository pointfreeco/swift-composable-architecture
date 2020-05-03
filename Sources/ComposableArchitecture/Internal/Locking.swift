import Foundation

extension UnsafeMutablePointer where Pointee == os_unfair_lock_s {
  @inlinable
  func sync<R>(_ work: () -> R) -> R {
    os_unfair_lock_lock(self)
    defer { os_unfair_lock_unlock(self) }
    return work()
  }
}

extension NSRecursiveLock {
  @inlinable
  func sync(work: () -> Void) {
    self.lock()
    defer { self.unlock() }
    work()
  }
}
