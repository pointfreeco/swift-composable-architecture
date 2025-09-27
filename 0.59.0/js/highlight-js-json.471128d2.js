/*!
 * This source file is part of the Swift.org open source project
 * 
 * Copyright (c) 2021 Apple Inc. and the Swift project authors
 * Licensed under Apache License v2.0 with Runtime Library Exception
 * 
 * See https://swift.org/LICENSE.txt for license information
 * See https://swift.org/CONTRIBUTORS.txt for Swift project authors
 */
(window["webpackJsonp"]=window["webpackJsonp"]||[]).push([["highlight-js-json"],{"5ad2":function(n,e){function a(n){const e={className:"attr",begin:/"(\\.|[^\\"\r\n])*"(?=\s*:)/,relevance:1.01},a={match:/[{}[\],:]/,className:"punctuation",relevance:0},s={beginKeywords:["true","false","null"].join(" ")};return{name:"JSON",contains:[e,a,n.QUOTE_STRING_MODE,s,n.C_NUMBER_MODE,n.C_LINE_COMMENT_MODE,n.C_BLOCK_COMMENT_MODE],illegal:"\\S"}}n.exports=a}}]);