//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Async Algorithms open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#include <stdint.h>

#if !defined(__has_feature)
#define __has_feature(x) 0
#endif

#if !defined(__has_attribute)
#define __has_attribute(x) 0
#endif

#if !defined(__has_builtin)
#define __has_builtin(builtin) 0
#endif

#if !defined(__has_cpp_attribute)
#define __has_cpp_attribute(attribute) 0
#endif

// TODO: These macro definitions are duplicated in BridgedSwiftObject.h. Move
// them to a single file if we find a location that both Visibility.h and
// BridgedSwiftObject.h can import.
#if __has_feature(nullability)
// Provide macros to temporarily suppress warning about the use of
// _Nullable and _Nonnull.
# define SWIFT_BEGIN_NULLABILITY_ANNOTATIONS                        \
  _Pragma("clang diagnostic push")                                  \
  _Pragma("clang diagnostic ignored \"-Wnullability-extension\"")
# define SWIFT_END_NULLABILITY_ANNOTATIONS                          \
  _Pragma("clang diagnostic pop")

#else
// #define _Nullable and _Nonnull to nothing if we're not being built
// with a compiler that supports them.
# define _Nullable
# define _Nonnull
# define SWIFT_BEGIN_NULLABILITY_ANNOTATIONS
# define SWIFT_END_NULLABILITY_ANNOTATIONS
#endif

#define SWIFT_MACRO_CONCAT(A, B) A ## B
#define SWIFT_MACRO_IF_0(IF_TRUE, IF_FALSE) IF_FALSE
#define SWIFT_MACRO_IF_1(IF_TRUE, IF_FALSE) IF_TRUE
#define SWIFT_MACRO_IF(COND, IF_TRUE, IF_FALSE) \
  SWIFT_MACRO_CONCAT(SWIFT_MACRO_IF_, COND)(IF_TRUE, IF_FALSE)

#if __has_attribute(pure)
#define SWIFT_READONLY __attribute__((__pure__))
#else
#define SWIFT_READONLY
#endif

#if __has_attribute(const)
#define SWIFT_READNONE __attribute__((__const__))
#else
#define SWIFT_READNONE
#endif

#if __has_attribute(always_inline)
#define SWIFT_ALWAYS_INLINE __attribute__((always_inline))
#else
#define SWIFT_ALWAYS_INLINE
#endif

#if __has_attribute(noinline)
#define SWIFT_NOINLINE __attribute__((__noinline__))
#else
#define SWIFT_NOINLINE
#endif

#if __has_attribute(noreturn)
#define SWIFT_NORETURN __attribute__((__noreturn__))
#else
#define SWIFT_NORETURN
#endif

#if __has_attribute(used)
#define SWIFT_USED __attribute__((__used__))
#else
#define SWIFT_USED
#endif

#if __has_attribute(unavailable)
#define SWIFT_ATTRIBUTE_UNAVAILABLE __attribute__((__unavailable__))
#else
#define SWIFT_ATTRIBUTE_UNAVAILABLE
#endif

#if (__has_attribute(weak_import))
#define SWIFT_WEAK_IMPORT __attribute__((weak_import))
#else
#define SWIFT_WEAK_IMPORT
#endif

// Define the appropriate attributes for sharing symbols across
// image (executable / shared-library) boundaries.
//
// SWIFT_ATTRIBUTE_FOR_EXPORTS will be placed on declarations that
// are known to be exported from the current image.  Typically, they
// are placed on header declarations and then inherited by the actual
// definitions.
//
// SWIFT_ATTRIBUTE_FOR_IMPORTS will be placed on declarations that
// are known to be exported from a different image.  This never
// includes a definition.
//
// Getting the right attribute on a declaratioon can be pretty awkward,
// but it's necessary under the C translation model.  All of this
// ceremony is familiar to Windows programmers; C/C++ programmers
// everywhere else usually don't bother, but since we have to get it
// right for Windows, we have everything set up to get it right on
// other targets as well, and doing so lets the compiler use more
// efficient symbol access patterns.
#if defined(__MACH__) || defined(__wasi__)

// On Mach-O and WebAssembly, we use non-hidden visibility.  We just use
// default visibility on both imports and exports, both because these
// targets don't support protected visibility but because they don't
// need it: symbols are not interposable outside the current image
// by default.
# define SWIFT_ATTRIBUTE_FOR_EXPORTS __attribute__((__visibility__("default")))
# define SWIFT_ATTRIBUTE_FOR_IMPORTS __attribute__((__visibility__("default")))

#elif defined(__ELF__)

// On ELF, we use non-hidden visibility.  For exports, we must use
// protected visibility to tell the compiler and linker that the symbols
// can't be interposed outside the current image.  For imports, we must
// use default visibility because protected visibility guarantees that
// the symbol is defined in the current library, which isn't true for
// an import.
//
// The compiler does assume that the runtime and standard library can
// refer to each other's symbols as DSO-local, so it's important that
// we get this right or we can get linker errors.
# define SWIFT_ATTRIBUTE_FOR_EXPORTS __attribute__((__visibility__("protected")))
# define SWIFT_ATTRIBUTE_FOR_IMPORTS __attribute__((__visibility__("default")))

#elif defined(__CYGWIN__)

// For now, we ignore all this on Cygwin.
# define SWIFT_ATTRIBUTE_FOR_EXPORTS
# define SWIFT_ATTRIBUTE_FOR_IMPORTS

// FIXME: this #else should be some sort of #elif Windows
#else // !__MACH__ && !__ELF__

// On PE/COFF, we use dllimport and dllexport.
# define SWIFT_ATTRIBUTE_FOR_EXPORTS __declspec(dllexport)
# define SWIFT_ATTRIBUTE_FOR_IMPORTS __declspec(dllimport)

#endif

// CMake conventionally passes -DlibraryName_EXPORTS when building
// code that goes into libraryName.  This isn't the best macro name,
// but it's conventional.  We do have to pass it explicitly in a few
// places in the build system for a variety of reasons.
//
// Unfortunately, defined(D) is a special function you can use in
// preprocessor conditions, not a macro you can use anywhere, so we
// need to manually check for all the libraries we know about so that
// we can use them in our condition below.s
#if defined(swiftCore_EXPORTS)
#define SWIFT_IMAGE_EXPORTS_swiftCore 1
#else
#define SWIFT_IMAGE_EXPORTS_swiftCore 0
#endif
#if defined(swift_Concurrency_EXPORTS)
#define SWIFT_IMAGE_EXPORTS_swift_Concurrency 1
#else
#define SWIFT_IMAGE_EXPORTS_swift_Concurrency 0
#endif
#if defined(swift_Distributed_EXPORTS)
#define SWIFT_IMAGE_EXPORTS_swift_Distributed 1
#else
#define SWIFT_IMAGE_EXPORTS_swift_Distributed 0
#endif
#if defined(swift_Differentiation_EXPORTS)
#define SWIFT_IMAGE_EXPORTS_swift_Differentiation 1
#else
#define SWIFT_IMAGE_EXPORTS_swift_Differentiation 0
#endif

#define SWIFT_EXPORT_FROM_ATTRIBUTE(LIBRARY)                          \
  SWIFT_MACRO_IF(SWIFT_IMAGE_EXPORTS_##LIBRARY,                       \
                 SWIFT_ATTRIBUTE_FOR_EXPORTS,                         \
                 SWIFT_ATTRIBUTE_FOR_IMPORTS)

// SWIFT_EXPORT_FROM(LIBRARY) declares something to be a C-linkage
// entity exported by the given library.
//
// SWIFT_RUNTIME_EXPORT is just SWIFT_EXPORT_FROM(swiftCore).
//
// TODO: use this in shims headers in overlays.
#if defined(__cplusplus)
#define SWIFT_EXPORT_FROM(LIBRARY) extern "C" SWIFT_EXPORT_FROM_ATTRIBUTE(LIBRARY)
#define SWIFT_EXPORT extern "C"
#else
#define SWIFT_EXPORT extern
#define SWIFT_EXPORT_FROM(LIBRARY) SWIFT_EXPORT_FROM_ATTRIBUTE(LIBRARY)
#endif
#define SWIFT_RUNTIME_EXPORT SWIFT_EXPORT_FROM(swiftCore)

// Define mappings for calling conventions.

// Annotation for specifying a calling convention of
// a runtime function. It should be used with declarations
// of runtime functions like this:
// void runtime_function_name() SWIFT_CC(swift)
#define SWIFT_CC(CC) SWIFT_CC_##CC

// SWIFT_CC(c) is the C calling convention.
#define SWIFT_CC_c

// SWIFT_CC(swift) is the Swift calling convention.
// FIXME: the next comment is false.
// Functions outside the stdlib or runtime that include this file may be built
// with a compiler that doesn't support swiftcall; don't define these macros
// in that case so any incorrect usage is caught.
#if __has_attribute(swiftcall)
#define SWIFT_CC_swift __attribute__((swiftcall))
#define SWIFT_CONTEXT __attribute__((swift_context))
#define SWIFT_ERROR_RESULT __attribute__((swift_error_result))
#define SWIFT_INDIRECT_RESULT __attribute__((swift_indirect_result))
#else
#define SWIFT_CC_swift
#define SWIFT_CONTEXT
#define SWIFT_ERROR_RESULT
#define SWIFT_INDIRECT_RESULT
#endif

typedef struct _Job* JobRef;

typedef SWIFT_CC(swift) void (*swift_task_enqueueGlobal_original)(JobRef _Nonnull job);
SWIFT_EXPORT_FROM(swift_Concurrency)
SWIFT_CC(swift) void (* _Nullable swift_task_enqueueGlobal_hook)(
  JobRef _Nonnull job, swift_task_enqueueGlobal_original _Nonnull original);

