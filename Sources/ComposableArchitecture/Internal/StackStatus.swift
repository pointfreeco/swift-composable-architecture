struct StackStatus {
  let stackSize: UInt
  let used: UInt

  var available: UInt { stackSize - used }
  var usedFraction: Double { Double(used) / Double(stackSize) }

  init() {
    let thread = pthread_self()
    let stackSize = UInt(pthread_get_stacksize_np(thread))
    let stackAddress = UInt(bitPattern: pthread_get_stackaddr_np(thread))
    var used: UInt = 0
    withUnsafeMutablePointer(to: &used) {
      let pointerAddress = UInt(bitPattern: $0)
      // Stack goes down on x86/64 and arm, but we rectify the result in any case this code
      // executes on another architecture using a different convention.
      $0.pointee =
        stackAddress > pointerAddress
        ? stackAddress - pointerAddress
        : pointerAddress - stackAddress
    }
    self.stackSize = stackSize
    self.used = used
  }
}
