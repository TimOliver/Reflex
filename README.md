<h1>Reflex</h1>


`Reflex` is an extension module for [FLEX](https://github.com/FLEXTool/FLEX) that brings first-class Swift type inspection to the debugger. Without Reflex, FLEX relies solely on the Objective-C runtime, which means that pure Swift classes, structs, enums, and their stored properties are either invisible or misrepresented in the inspector.

Reflex closes this gap by bridging [Echo](https://github.com/Azoy/Echo) — a library that reads Swift's own runtime type metadata directly — into the `FLEXMirrorProtocol` interface that FLEX uses to inspect any object. The result is that Swift types appear in FLEX with correctly-named ivars, proper type encodings, accurate sizes and offsets, and full protocol-conformance lists, just as if they were plain Objective-C objects.

> **Note:** Because Reflex depends on FLEX, which uses private Apple APIs, it cannot be included in an App Store submission. It is intended exclusively for use in debug builds.

# Features

* Surfaces stored properties on **pure Swift classes** that the ObjC runtime cannot see.
* Correctly reports **field names, types, sizes, and byte offsets** for every Swift ivar.
* Supports **getting and setting** Swift ivar values through FLEX's inspector UI.
* Handles **optional types** correctly — setting nil uses `_openExistential` to produce a properly-typed `Optional.none` rather than naively zeroing memory.
* Bridges **Foundation value types** (`String`, `Data`, `URL`, `Date`, `[T]`, `[K:V]`) to their Objective-C class equivalents for correct type encoding.
* Exposes **Swift protocol conformances** alongside ObjC protocols in the protocols list.
* Traverses the **full class hierarchy** when getting or setting values, including fields declared on superclasses.
* Provides accurate **type encoding strings** for scalars, structs, tuples, enums, and bridged types.
* Gracefully handles **non-Swift types**, ObjC classes, and `__SwiftValue` boxes without crashing.
* Fully interoperable with Objective-C via `FLEXSwiftMirror`, `FLEXSwiftIvar`, and `FLEXSwiftProtocol`.

# Usage

Reflex is designed to integrate directly with FLEX. Register `SwiftMirror` as FLEX's Swift mirror class at launch and the debugger will automatically use it when reflecting Swift objects.

```swift
import FLEX
import Reflex

// In your AppDelegate or debug setup code:
FLEXManager.shared.swiftMirrorClass = SwiftMirror.self
```

You can also use `SwiftMirror` independently to inspect any Swift object at runtime:

```swift
import Reflex

let inspector = SwiftMirror(reflecting: someSwiftObject)

// Print all ivar names, types, and current values
for ivar in inspector.ivars {
    let value = ivar.getValue(someSwiftObject) ?? "nil"
    print("\(ivar.name): \(ivar.typeEncoding) = \(value)")
}

// Traverse the class hierarchy
var mirror: FLEXMirrorProtocol? = inspector
while let current = mirror {
    print("Class: \(current.className), ivars: \(current.ivars.count)")
    mirror = current.superMirror
}
```

Setting values works too — Reflex handles type mismatches such as `NSNumber` being passed for an `Int` field by performing a dynamic cast first:

```swift
// Directly set a field value by name on a Swift class instance
let meta = reflectClass(someObject) as! ClassMetadata
meta.set(value: "New Value", forKey: "title", pointer: someObject~)
```

# Requirements

* iOS 12.0 or later
* Swift 5.0 or later
* [FLEX](https://github.com/FLEXTool/FLEX) 4.6 or later
* [Echo](https://github.com/TimOliver/Echo)

# Installation

## Swift Package Manager

Add the following to your `Package.swift` dependencies:

```swift
.package(url: "https://github.com/TimOliver/Reflex", from: "1.0.0")
```

Then add `"Reflex"` to your target's dependencies array.

# Credits

`Reflex` was created by [Tanner Bennett](https://github.com/tannerbennett), and builds upon [Echo](https://github.com/Azoy/Echo) by [Alejandro Alonso](https://github.com/Azoy).

# License

`Reflex` is available under the BSD license. Please see the [LICENSE](LICENSE) file for more information. Note that because this library depends on FLEX, which uses private Apple APIs, it **cannot be used in App Store submissions**.
