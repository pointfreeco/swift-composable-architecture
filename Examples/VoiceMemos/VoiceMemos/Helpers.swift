import Foundation

struct AlertData: Identifiable {
  var message: String
  var id: String { self.message }
}

let dateFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .medium
  return formatter
}()

let dateComponentsFormatter: DateComponentsFormatter = {
  let formatter = DateComponentsFormatter()
  formatter.allowedUnits = [.minute, .second]
  formatter.zeroFormattingBehavior = .pad
  return formatter
}()
