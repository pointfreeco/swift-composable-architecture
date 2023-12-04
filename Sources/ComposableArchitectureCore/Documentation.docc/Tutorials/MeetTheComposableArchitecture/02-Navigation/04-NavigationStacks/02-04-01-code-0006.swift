import SwiftUI

struct ContactDetailView: View {
  let store: StoreOf<ContactDetailFeature>
  
  var body: some View {
    Form {
    }
    .navigationBarTitle(Text(store.contact.name))
  }
}
