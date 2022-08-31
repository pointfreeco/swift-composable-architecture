
var viewStoreInitCount = 0
var viewStoreObjectWillChangeCount = 0

func instrument(_ value: inout Int, message: String) {
  value += 1
  print(message, value)
}
