import SwiftUI

struct ContactDetailView: View {
  let store: StoreOf<ContactDetailFeature>
  
  var body: some View {
    Form {
    }
    .navigationTitle(Text(store.contact.name))
  }
}
