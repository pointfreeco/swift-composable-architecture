import ConcurrencyExtras

@_spi(Internals) public enum SharedLocals {
  @_spi(Internals) @TaskLocal public static var changeTracker: SharedChangeTracker?
}
