# Case paths

Learn about the role that case paths play in composing features in this library.

## Overview

[Case paths](http://github.com/pointfreeco/swift-case-paths) are a concept that were highly 
motivated by the development of the Composable Architecture. They are similar to Swift's key paths,
which are a powerful abstract for the getting and setting of a value inside a root, but case paths
are tuned specifically to work for cases in an enum. They abstract over the two fundamental 
operations one can do with an enum: attempt to extract a case's value from it, and embed a case's
value into it.

The Composable Architecture uses case paths heavily to facilitate composition of features, both
at the level of ``Reducer``s and also for views.

## Composing reducers

Many reducers and reducer operators that ship with the library involve case paths in some form, such
as ``Scope`` for running a child reducer on some child state embedded in the parent domain, 
``Reducer/ifLet(_:action:destination:fileID:line:)-4f2at`` for running a child reducer on a 
piece of optional state, and ``Reducer/forEach(_:action:element:fileID:line:)-8ujke`` for running
a child reducer on each element of a collection of child states. The `action` argument of each of
these APIs takes what is known as a `CaseKeyPath`, which is key path that 

## The `@CasePathable` macro

## Other uses of case paths

<!--### Section header-->
<!---->
<!--<!--@START_MENU_TOKEN@-->Text<!--@END_MENU_TOKEN@-->-->
