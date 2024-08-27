# Migrating to 1.14

The ``Store`` type is now officially `@MainActor` isolated. 

## Overview

As the library prepares for Swift 6 we are in the process of updating the library's APIs for 
sendability and isolation where appropriate, and doing so in a backwards compatible way. Prior
to version 1.14 of the library the ``Store`` type has only ever been meant to be used on the
main thread, but that contract was not enforced in any major way. If a store was interacted with
on a background thread a runtime warning would be emitted, but the compiler had no knowledge of
the type's isolation.

That now changes in 1.14 where ``Store`` is now officially `@MainActor`-isolated. This has been
done in a way that should be 100% backwards compatible, and if you have problems please open a
[discussion][tca-discussion].

However, if you are using _strict_ concurrency settings in your app, then there is one circumstance
in which you may have a compilation error. If you are accessing the `store` in a view method or
property in Xcode <16, then you may have to mark that property as `@MainActor`:

```diff
 struct FeatureView: View {
   let store: StoreOf<Feature>
 
   var body: some View {
     // ...
   }
 
+  @MainActor
   var title: some View {
     Text(store.name)
   }
 }
```

[tca-discussion]: http://github.com/pointfreeco/swift-composable-architecture/discussions
