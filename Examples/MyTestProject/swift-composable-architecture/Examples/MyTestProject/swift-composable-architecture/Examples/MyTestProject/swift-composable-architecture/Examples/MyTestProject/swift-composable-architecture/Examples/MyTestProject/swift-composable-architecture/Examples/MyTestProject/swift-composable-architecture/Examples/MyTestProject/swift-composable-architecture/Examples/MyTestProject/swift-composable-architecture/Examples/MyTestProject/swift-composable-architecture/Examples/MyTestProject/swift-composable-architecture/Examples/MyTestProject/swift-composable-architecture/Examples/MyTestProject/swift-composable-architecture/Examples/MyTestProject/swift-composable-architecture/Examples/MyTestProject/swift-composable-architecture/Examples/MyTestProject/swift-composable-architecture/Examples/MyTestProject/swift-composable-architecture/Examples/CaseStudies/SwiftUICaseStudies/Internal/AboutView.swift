import SwiftUI

struct AboutView: View {
  let readMe: String

  var body: some View {
    DisclosureGroup("About this case study") {
      Text(template: self.readMe)
    }
  }
}
