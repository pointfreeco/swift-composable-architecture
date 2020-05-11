typealias XCTCurrentTestCase = @convention(c) () -> AnyObject
typealias XCTFailureHandler
  = @convention(c) (AnyObject, Bool, UnsafePointer<CChar>, UInt, String, String?) -> Void
