//
//  PointerExtensions.swift
//
//  Copyright (c) Flipboard, Inc. (2014–2016); Tanner Bennett (2021-2026)
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice, this
//  list of conditions and the following disclaimer in the documentation and/or
//  other materials provided with the distribution.
//
//  * Neither the name of Flipboard nor the names of its
//  contributors may be used to endorse or promote products derived from
//  this software without specific prior written permission.
//
//  * You must NOT include this project in an application to be submitted
//  to the App Store™, as this project uses too many private APIs.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
//  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
//  ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


import Foundation
import Echo

/// A mutable raw pointer used throughout Reflex as a universal storage handle.
typealias RawPointer = UnsafeMutableRawPointer

extension UnsafeRawPointer {
    /// Loads a value of type `T` from the given byte offset without advancing the pointer.
    ///
    /// - Parameter offset: The number of bytes from this pointer at which to read.
    /// - Returns: The value of type `T` stored at the specified byte offset.
    subscript<T>(offset: Int) -> T {
        get {
            return self.load(fromByteOffset: offset, as: T.self)
        }
    }
}

extension RawPointer {
    /// Loads or stores a value of type `T` at the given byte offset.
    ///
    /// - Warning: Do not use when `T` is `Any` unless you specifically intend to
    ///   read/write the raw `Any` existential representation.
    ///
    /// - Parameter offset: The number of bytes from this pointer at which to read or write.
    subscript<T>(offset: Int) -> T {
        get {
            return self.load(fromByteOffset: offset, as: T.self)
        }

        set {
            self.storeBytes(of: newValue, toByteOffset: offset, as: T.self)
        }
    }

    /// Allocates an uninitialized buffer large enough to hold one instance of the given type.
    ///
    /// The buffer is sized and aligned according to the type's value-witness table.
    /// The caller is responsible for initializing and eventually deallocating the buffer.
    ///
    /// - Parameter type: The Echo `Metadata` describing the type to allocate storage for.
    /// - Returns: A freshly allocated, uninitialized `RawPointer` of the appropriate size.
    static func allocateBuffer(for type: Metadata) -> Self {
        return RawPointer.allocate(
            byteCount: type.vwt.size,
            alignment: type.vwt.flags.alignment
        )
    }

    /// Allocates a buffer and immediately stores a value into it.
    ///
    /// This is a low-level convenience. Prefer ``AnyExistentialContainer`` for most use cases,
    /// as it manages the buffer lifetime and inline/heap distinction automatically.
    ///
    /// - Parameters:
    ///   - value: The `Any`-boxed value to copy into the newly allocated buffer.
    ///   - metadata: The Echo `Metadata` for the type being stored, used for sizing and copy.
    init(wrapping value: Any, withType metadata: Metadata) {
        self = RawPointer.allocateBuffer(for: metadata)
        self.storeBytes(of: value, type: metadata)
    }

    /// Copies the value held in an `Any` container into this buffer at the given byte offset.
    ///
    /// The value is projected out of its existential container and copied using the type's
    /// value-witness `initializeWithCopy`, ensuring proper reference counting.
    ///
    /// - Parameters:
    ///   - value: The `Any`-boxed value whose storage will be copied.
    ///   - type: The Echo `Metadata` for the value's type, used to drive the copy.
    ///   - offset: The byte offset within this buffer at which to write. Defaults to `0`.
    func storeBytes(of value: Any, type: Metadata, offset: Int = 0) {
        var box = container(for: value)
        type.vwt.initializeWithCopy((self + offset), box.projectValue()~)
//        (self + offset).copyMemory(from: box.projectValue(), byteCount: type.vwt.size)
    }

    /// Copies a single tuple element's value from the given source pointer into this buffer.
    ///
    /// The destination offset within this buffer is taken from the element's layout descriptor.
    /// The copy uses `initializeWithCopy` from the element type's value-witness table.
    ///
    /// - Parameters:
    ///   - valuePtr: A pointer to the start of the tuple element's storage in memory.
    ///   - e: The `TupleMetadata.Element` describing the element's type and offset within the tuple.
    func copyMemory(ofTupleElement valuePtr: UnsafeRawPointer, layout e: TupleMetadata.Element) {
        e.metadata.vwt.initializeWithCopy((self + e.offset), valuePtr~)
//        (self + e.offset).copyMemory(from: valuePtr, byteCount: e.metadata.vwt.size)
    }

    /// Copies a typed value from the given source pointer into this buffer at the given byte offset.
    ///
    /// Uses `initializeWithCopy` from the type's value-witness table to ensure correct
    /// ownership semantics for reference types and copy-on-write types.
    ///
    /// - Parameters:
    ///   - pointer: The source `RawPointer` to copy from.
    ///   - type: The Echo `Metadata` for the value's type, used to drive the copy.
    ///   - offset: The byte offset within this buffer at which to write. Defaults to `0`.
    func copyMemory(from pointer: RawPointer, type: Metadata, offset: Int = 0) {
        type.vwt.initializeWithCopy((self + offset), pointer)
//        (self + offset).copyMemory(from: pointer, byteCount: type.vwt.size)
    }
}

extension Unmanaged where Instance == AnyObject {
    /// Retains `thing` if it is a reference type (class or ObjC object), and does nothing otherwise.
    ///
    /// Use this before writing a reference type's address to raw memory to prevent the object
    /// from being deallocated while the raw pointer is still live.
    ///
    /// - Parameter thing: The value to conditionally retain.
    /// - Returns: `true` if `thing` was retained as an object; `false` if it is a value type.
    @discardableResult
    static func retainIfObject(_ thing: Any) -> Bool {
        if container(for: thing).metadata.kind.isObject {
            _ = self.passRetained(thing as AnyObject).retain()
            return true
        }

        return false
    }
}

/// Postfix `~`: reinterprets any value as a `RawPointer` via `unsafeBitCast`.
///
/// Safe only when `target` is pointer-sized: class instances, metatypes, or an existing
/// `RawPointer`. Using this on a struct larger than a pointer will produce a garbage pointer.
postfix operator ~
postfix func ~<T>(target: T) -> RawPointer {
    return unsafeBitCast(target, to: RawPointer.self)
}

/// Prefix `~`: reinterprets any value as an arbitrary type `U` via `unsafeBitCast`.
///
/// The caller is responsible for ensuring that `target` and `U` have the same size
/// and that the resulting bit pattern is a valid representation of `U`.
prefix func ~<T,U>(target: T) -> U {
    return unsafeBitCast(target, to: U.self)
}
