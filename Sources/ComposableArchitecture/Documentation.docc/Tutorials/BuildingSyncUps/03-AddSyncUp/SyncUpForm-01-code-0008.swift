import ComposableArchitecture

@Reducer
struct SyncUpForm {
  // ...
}

struct SyncUpFormView: View {
  @Bindable var store: StoreOf<SyncUpForm>
  
  var body: some View {
    Form {
      
    }
  }
}
