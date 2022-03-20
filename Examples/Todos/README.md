# Todos

This simple todo application built with the Composable Architecture includes a few bells and whistles:

* Filtering and rearranging todo items.
* Automatically sort completed todos to the bottom of the list.
* Debouncing the sort action to allow multiple todo items to be toggled before being sorted.
* A comprehensive test suite.


## Amplify Integration

1. `amplify init`

2. `amplify add api`, GraphQL, and use the following schema

```
type Todo @model {
  description: String!
  id: ID!
  isComplete: Boolean!
}
```

3. `amplify push`

4. Add dependencies to the project. In the Xcode project, File -> Add Packages... -> Enter URL: `https://github.com/aws-amplify/amplify-ios.git`
Select the `amplify-ios` package and click Add Package.

5. Under 'Choose Package Products for amplify-ios', choose the following

- AWSAPIPlugin
- AWSDataStorePlugin
- AWSPluginsCore
- Amplify

5. `amplify codegen models`

6. 
