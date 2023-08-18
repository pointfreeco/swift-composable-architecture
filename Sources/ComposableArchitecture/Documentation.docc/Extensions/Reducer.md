# ``ComposableArchitecture/Reducer``

## Topics

### Implementing a reducer

- ``State``
- ``Action``
- ``body-swift.property``
- ``Reduce``
- ``Effect``

### Reducer composition

- ``ReducerBuilder``

### Embedding child features

- ``Scope``
- ``ifLet(_:action:then:fileID:line:)``
- ``ifCaseLet(_:action:then:fileID:line:)``
- ``forEach(_:action:element:fileID:line:)``

### Supporting reducers

- ``CombineReducers``
- ``EmptyReducer``
- ``BindingReducer``

### Reducer modifiers

- ``dependency(_:_:)``
- ``transformDependency(_:transform:)``
- ``onChange(of:_:)``
- ``signpost(_:log:)``
- ``_printChanges(_:)``

### Supporting types

- ``ReducerOf``
