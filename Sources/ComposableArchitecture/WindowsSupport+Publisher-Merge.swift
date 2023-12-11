#if !canImport(Combine)
import OpenCombine

// Verbatim copy of
// https://github.com/cx-org/CombineX/blob/299bc0f8861f7aa6708780457aeeafab1c51eaa7/Sources/CombineX/Publishers/B/Merge.swift and
// https://github.com/cx-org/CombineX/blob/299bc0f8861f7aa6708780457aeeafab1c51eaa7/Sources/CombineX/Publishers/B/Combined/Merge%2B.swift#L5
// to make Effect's `merge` work on Windows using OpenCombine.

// MIT License

// Copyright (c) 2019 Quentin Jin

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

extension Publisher {

    /// Combines elements from this publisher with those from another publisher, delivering an interleaved sequence of elements.
    ///
    /// The merged publisher continues to emit elements until all upstream publishers finish. If an upstream publisher produces an error, the merged publisher fails with that error.
    /// - Parameter other: Another publisher.
    /// - Returns: A publisher that emits an event when either upstream publisher emits an event.
    public func merge<P: Publisher>(with other: P) -> Publishers.Merge<Self, P> where Failure == P.Failure, Output == P.Output {
        return .init(self, other)
    }
}

extension Publishers.Merge: Equatable where A: Equatable, B: Equatable {

    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A merging publisher to compare for equality.
    ///   - rhs: Another merging publisher to compare for equality..
    /// - Returns: `true` if the two merging - rhs: Another merging publisher to compare for equality.
    public static func == (lhs: Publishers.Merge<A, B>, rhs: Publishers.Merge<A, B>) -> Bool {
        return lhs.a == rhs.a && rhs.b == rhs.b
    }
}

extension Publishers {

    /// A publisher created by applying the merge function to two upstream publishers.
    public struct Merge<A, B>: Publisher where A: Publisher, B: Publisher, A.Failure == B.Failure, A.Output == B.Output {

        public typealias Output = A.Output

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        let pub: AnyPublisher<A.Output, A.Failure>

        public init(_ a: A, _ b: B) {
            self.a = a
            self.b = b

            self.pub = Publishers
                .Sequence(sequence: [a.eraseToAnyPublisher(), b.eraseToAnyPublisher()])
                .flatMap { $0 }
                .eraseToAnyPublisher()
        }

        public func receive<S: Subscriber>(subscriber: S) where B.Failure == S.Failure, B.Output == S.Input {
            self.pub.subscribe(subscriber)
        }

        public func merge<P: Publisher>(with other: P) -> Publishers.Merge3<A, B, P> where B.Failure == P.Failure, B.Output == P.Output {
            return .init(self.a, self.b, other)
        }

        public func merge<Z, Y>(with z: Z, _ y: Y) -> Publishers.Merge4<A, B, Z, Y> where Z: Publisher, Y: Publisher, B.Failure == Z.Failure, B.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output {
            return .init(self.a, self.b, z, y)
        }

        public func merge<Z, Y, X>(with z: Z, _ y: Y, _ x: X) -> Publishers.Merge5<A, B, Z, Y, X> where Z: Publisher, Y: Publisher, X: Publisher, B.Failure == Z.Failure, B.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output {
            return .init(self.a, self.b, z, y, x)
        }

        public func merge<Z, Y, X, W>(with z: Z, _ y: Y, _ x: X, _ w: W) -> Publishers.Merge6<A, B, Z, Y, X, W> where Z: Publisher, Y: Publisher, X: Publisher, W: Publisher, B.Failure == Z.Failure, B.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output, X.Failure == W.Failure, X.Output == W.Output {
            return .init(self.a, self.b, z, y, x, w)
        }

        public func merge<Z, Y, X, W, V>(with z: Z, _ y: Y, _ x: X, _ w: W, _ v: V) -> Publishers.Merge7<A, B, Z, Y, X, W, V> where Z: Publisher, Y: Publisher, X: Publisher, W: Publisher, V: Publisher, B.Failure == Z.Failure, B.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output, X.Failure == W.Failure, X.Output == W.Output, W.Failure == V.Failure, W.Output == V.Output {
            return .init(self.a, self.b, z, y, x, w, v)
        }

        public func merge<Z, Y, X, W, V, U>(with z: Z, _ y: Y, _ x: X, _ w: W, _ v: V, _ u: U) -> Publishers.Merge8<A, B, Z, Y, X, W, V, U> where Z: Publisher, Y: Publisher, X: Publisher, W: Publisher, V: Publisher, U: Publisher, B.Failure == Z.Failure, B.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output, X.Failure == W.Failure, X.Output == W.Output, W.Failure == V.Failure, W.Output == V.Output, V.Failure == U.Failure, V.Output == U.Output {
            return .init(self.a, self.b, z, y, x, w, v, u)
        }
    }
}

extension Publisher {

    /// Combines elements from this publisher with those from two other publishers, delivering an interleaved sequence of elements.
    ///
    /// The merged publisher continues to emit elements until all upstream publishers finish. If an upstream publisher produces an error, the merged publisher fails with that error.
    ///
    /// - Parameters:
    ///   - b: A second publisher.
    ///   - c: A third publisher.
    /// - Returns:  A publisher that emits an event when any upstream publisher emits
    /// an event.
    public func merge<B, C>(with b: B, _ c: C) -> Publishers.Merge3<Self, B, C> where B: Publisher, C: Publisher, Failure == B.Failure, Output == B.Output, B.Failure == C.Failure, B.Output == C.Output {
        return .init(self, b, c)
    }

    /// Combines elements from this publisher with those from three other publishers, delivering
    /// an interleaved sequence of elements.
    ///
    /// The merged publisher continues to emit elements until all upstream publishers finish. If an upstream publisher produces an error, the merged publisher fails with that error.
    ///
    /// - Parameters:
    ///   - b: A second publisher.
    ///   - c: A third publisher.
    ///   - d: A fourth publisher.
    /// - Returns: A publisher that emits an event when any upstream publisher emits an event.
    public func merge<B, C, D>(with b: B, _ c: C, _ d: D) -> Publishers.Merge4<Self, B, C, D> where B: Publisher, C: Publisher, D: Publisher, Failure == B.Failure, Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output {
        return .init(self, b, c, d)
    }

    /// Combines elements from this publisher with those from four other publishers, delivering an interleaved sequence of elements.
    ///
    /// The merged publisher continues to emit elements until all upstream publishers finish. If an upstream publisher produces an error, the merged publisher fails with that error.
    ///
    /// - Parameters:
    ///   - b: A second publisher.
    ///   - c: A third publisher.
    ///   - d: A fourth publisher.
    ///   - e: A fifth publisher.
    /// - Returns: A publisher that emits an event when any upstream publisher emits an event.
    public func merge<B, C, D, E>(with b: B, _ c: C, _ d: D, _ e: E) -> Publishers.Merge5<Self, B, C, D, E> where B: Publisher, C: Publisher, D: Publisher, E: Publisher, Failure == B.Failure, Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output, D.Failure == E.Failure, D.Output == E.Output {
        return .init(self, b, c, d, e)
    }

    /// Combines elements from this publisher with those from five other publishers, delivering an interleaved sequence of elements.
    ///
    /// The merged publisher continues to emit elements until all upstream publishers finish. If an upstream publisher produces an error, the merged publisher fails with that error.
    ///
    /// - Parameters:
    ///   - b: A second publisher.
    ///   - c: A third publisher.
    ///   - d: A fourth publisher.
    ///   - e: A fifth publisher.
    ///   - f: A sixth publisher.
    /// - Returns: A publisher that emits an event when any upstream publisher emits an event.
    public func merge<B, C, D, E, F>(with b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> Publishers.Merge6<Self, B, C, D, E, F> where B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, Failure == B.Failure, Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output, D.Failure == E.Failure, D.Output == E.Output, E.Failure == F.Failure, E.Output == F.Output {
        return .init(self, b, c, d, e, f)
    }

    /// Combines elements from this publisher with those from six other publishers, delivering an interleaved sequence of elements.
    ///
    /// The merged publisher continues to emit elements until all upstream publishers finish. If an upstream publisher produces an error, the merged publisher fails with that error.
    ///
    /// - Parameters:
    ///   - b: A second publisher.
    ///   - c: A third publisher.
    ///   - d: A fourth publisher.
    ///   - e: A fifth publisher.
    ///   - f: A sixth publisher.
    ///   - g: A seventh publisher.
    /// - Returns: A publisher that emits an event when any upstream publisher emits an event.
    public func merge<B, C, D, E, F, G>(with b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> Publishers.Merge7<Self, B, C, D, E, F, G> where B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, G: Publisher, Failure == B.Failure, Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output, D.Failure == E.Failure, D.Output == E.Output, E.Failure == F.Failure, E.Output == F.Output, F.Failure == G.Failure, F.Output == G.Output {
        return .init(self, b, c, d, e, f, g)
    }

    /// Combines elements from this publisher with those from seven other publishers, delivering an interleaved sequence of elements.
    ///
    /// The merged publisher continues to emit elements until all upstream publishers finish. If an upstream publisher produces an error, the merged publisher fails with that error.
    ///
    /// - Parameters:
    ///   - b: A second publisher.
    ///   - c: A third publisher.
    ///   - d: A fourth publisher.
    ///   - e: A fifth publisher.
    ///   - f: A sixth publisher.
    ///   - g: A seventh publisher.
    ///   - h: An eighth publisher.
    /// - Returns: A publisher that emits an event when any upstream publisher emits an event.
    public func merge<B, C, D, E, F, G, H>(with b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) -> Publishers.Merge8<Self, B, C, D, E, F, G, H> where B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, G: Publisher, H: Publisher, Failure == B.Failure, Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output, D.Failure == E.Failure, D.Output == E.Output, E.Failure == F.Failure, E.Output == F.Output, F.Failure == G.Failure, F.Output == G.Output, G.Failure == H.Failure, G.Output == H.Output {
        return .init(self, b, c, d, e, f, g, h)
    }

    /// Combines elements from this publisher with those from another publisher of the same type, delivering an interleaved sequence of elements.
    ///
    /// - Parameter other: Another publisher of this publisher's type.
    /// - Returns: A publisher that emits an event when either upstream publisher emits
    /// an event.
    public func merge(with other: Self) -> Publishers.MergeMany<Self> {
        return .init(self, other)
    }
}

extension Publishers.Merge3: Equatable where A: Equatable, B: Equatable, C: Equatable {

    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A merging publisher to compare for equality.
    ///   - rhs: Another merging publisher to compare for equality.
    /// - Returns: `true` if the two merging publishers have equal source publishers, `false` otherwise.
    public static func == (lhs: Publishers.Merge3<A, B, C>, rhs: Publishers.Merge3<A, B, C>) -> Bool {
        return lhs.a == rhs.a
            && lhs.b == rhs.b
            && lhs.c == rhs.c
    }
}

extension Publishers.Merge4: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable {

    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A merging publisher to compare for equality.
    ///   - rhs: Another merging publisher to compare for equality.
    /// - Returns: `true` if the two merging publishers have equal source publishers, `false` otherwise.
    public static func == (lhs: Publishers.Merge4<A, B, C, D>, rhs: Publishers.Merge4<A, B, C, D>) -> Bool {
        return lhs.a == rhs.a
            && lhs.b == rhs.b
            && lhs.c == rhs.c
            && lhs.d == rhs.d
    }
}

extension Publishers.Merge5: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable {

    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A merging publisher to compare for equality.
    ///   - rhs: Another merging publisher to compare for equality.
    /// - Returns: `true` if the two merging publishers have equal source publishers, `false` otherwise.
    public static func == (lhs: Publishers.Merge5<A, B, C, D, E>, rhs: Publishers.Merge5<A, B, C, D, E>) -> Bool {
        return lhs.a == rhs.a
            && lhs.b == rhs.b
            && lhs.c == rhs.c
            && lhs.d == rhs.d
            && lhs.e == rhs.e
    }
}

extension Publishers.Merge6: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable, F: Equatable {

    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A merging publisher to compare for equality.
    ///   - rhs: Another merging publisher to compare for equality.
    /// - Returns: `true` if the two merging publishers have equal source publishers, `false` otherwise.
    public static func == (lhs: Publishers.Merge6<A, B, C, D, E, F>, rhs: Publishers.Merge6<A, B, C, D, E, F>) -> Bool {
        return lhs.a == rhs.a
            && lhs.b == rhs.b
            && lhs.c == rhs.c
            && lhs.d == rhs.d
            && lhs.e == rhs.e
            && lhs.f == rhs.f
    }
}

extension Publishers.Merge7: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable, F: Equatable, G: Equatable {

    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A merging publisher to compare for equality.
    ///   - rhs: Another merging publisher to compare for equality.
    /// - Returns: `true` if the two merging publishers have equal source publishers, `false` otherwise.
    public static func == (lhs: Publishers.Merge7<A, B, C, D, E, F, G>, rhs: Publishers.Merge7<A, B, C, D, E, F, G>) -> Bool {
        return lhs.a == rhs.a
            && lhs.b == rhs.b
            && lhs.c == rhs.c
            && lhs.d == rhs.d
            && lhs.e == rhs.e
            && lhs.f == rhs.f
            && lhs.g == rhs.g
    }
}

extension Publishers.Merge8: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable, F: Equatable, G: Equatable, H: Equatable {

    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A merging publisher to compare for equality.
    ///   - rhs: Another merging publisher to compare for equality.
    /// - Returns: `true` if the two merging publishers have equal source publishers, `false` otherwise.
    public static func == (lhs: Publishers.Merge8<A, B, C, D, E, F, G, H>, rhs: Publishers.Merge8<A, B, C, D, E, F, G, H>) -> Bool {
        return lhs.a == rhs.a
            && lhs.b == rhs.b
            && lhs.c == rhs.c
            && lhs.d == rhs.d
            && lhs.e == rhs.e
            && lhs.f == rhs.f
            && lhs.g == rhs.g
            && lhs.h == rhs.h
    }
}

extension Publishers.MergeMany: Equatable where Upstream: Equatable {

    public static func == (lhs: Publishers.MergeMany<Upstream>, rhs: Publishers.MergeMany<Upstream>) -> Bool {
        return lhs.publishers == rhs.publishers
    }
}

extension Publishers {

    /// A publisher created by applying the merge function to three upstream publishers.
    public struct Merge3<A, B, C>: Publisher where A: Publisher, B: Publisher, C: Publisher, A.Failure == B.Failure, A.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output {

        public typealias Output = A.Output

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        let pub: AnyPublisher<A.Output, A.Failure>

        public init(_ a: A, _ b: B, _ c: C) {
            self.a = a
            self.b = b
            self.c = c

            self.pub = Publishers
                .Sequence(sequence: [
                    a.eraseToAnyPublisher(),
                    b.eraseToAnyPublisher(),
                    c.eraseToAnyPublisher()
                ])
                .flatMap { $0 }
                .eraseToAnyPublisher()
        }

        public func receive<S: Subscriber>(subscriber: S) where C.Failure == S.Failure, C.Output == S.Input {
            self.pub.subscribe(subscriber)
        }

        public func merge<P: Publisher>(with other: P) -> Publishers.Merge4<A, B, C, P> where C.Failure == P.Failure, C.Output == P.Output {
            return .init(a, b, c, other)
        }

        public func merge<Z, Y>(with z: Z, _ y: Y) -> Publishers.Merge5<A, B, C, Z, Y> where Z: Publisher, Y: Publisher, C.Failure == Z.Failure, C.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output {
            return .init(a, b, c, z, y)
        }

        public func merge<Z, Y, X>(with z: Z, _ y: Y, _ x: X) -> Publishers.Merge6<A, B, C, Z, Y, X> where Z: Publisher, Y: Publisher, X: Publisher, C.Failure == Z.Failure, C.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output {
            return .init(a, b, c, z, y, x)
        }

        public func merge<Z, Y, X, W>(with z: Z, _ y: Y, _ x: X, _ w: W) -> Publishers.Merge7<A, B, C, Z, Y, X, W> where Z: Publisher, Y: Publisher, X: Publisher, W: Publisher, C.Failure == Z.Failure, C.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output, X.Failure == W.Failure, X.Output == W.Output {
            return .init(a, b, c, z, y, x, w)
        }

        public func merge<Z, Y, X, W, V>(with z: Z, _ y: Y, _ x: X, _ w: W, _ v: V) -> Publishers.Merge8<A, B, C, Z, Y, X, W, V> where Z: Publisher, Y: Publisher, X: Publisher, W: Publisher, V: Publisher, C.Failure == Z.Failure, C.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output, X.Failure == W.Failure, X.Output == W.Output, W.Failure == V.Failure, W.Output == V.Output {
            return .init(a, b, c, z, y, x, w, v)
        }
    }

    /// A publisher created by applying the merge function to four upstream publishers.
    public struct Merge4<A, B, C, D>: Publisher where A: Publisher, B: Publisher, C: Publisher, D: Publisher, A.Failure == B.Failure, A.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output {

        public typealias Output = A.Output

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public let d: D

        let pub: AnyPublisher<A.Output, A.Failure>

        public init(_ a: A, _ b: B, _ c: C, _ d: D) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d

            self.pub = Publishers
                .Sequence(sequence: [
                    a.eraseToAnyPublisher(),
                    b.eraseToAnyPublisher(),
                    c.eraseToAnyPublisher(),
                    d.eraseToAnyPublisher()
                ])
                .flatMap { $0 }
                .eraseToAnyPublisher()
        }

        public func receive<S: Subscriber>(subscriber: S) where D.Failure == S.Failure, D.Output == S.Input {
            self.pub.subscribe(subscriber)
        }

        public func merge<P: Publisher>(with other: P) -> Publishers.Merge5<A, B, C, D, P> where D.Failure == P.Failure, D.Output == P.Output {
            return .init(a, b, c, d, other)
        }

        public func merge<Z, Y>(with z: Z, _ y: Y) -> Publishers.Merge6<A, B, C, D, Z, Y> where Z: Publisher, Y: Publisher, D.Failure == Z.Failure, D.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output {
            return .init(a, b, c, d, z, y)
        }

        public func merge<Z, Y, X>(with z: Z, _ y: Y, _ x: X) -> Publishers.Merge7<A, B, C, D, Z, Y, X> where Z: Publisher, Y: Publisher, X: Publisher, D.Failure == Z.Failure, D.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output {
            return .init(a, b, c, d, z, y, x)
        }

        public func merge<Z, Y, X, W>(with z: Z, _ y: Y, _ x: X, _ w: W) -> Publishers.Merge8<A, B, C, D, Z, Y, X, W> where Z: Publisher, Y: Publisher, X: Publisher, W: Publisher, D.Failure == Z.Failure, D.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output, X.Failure == W.Failure, X.Output == W.Output {
            return .init(a, b, c, d, z, y, x, w)
        }
    }

    /// A publisher created by applying the merge function to five upstream publishers.
    public struct Merge5<A, B, C, D, E>: Publisher where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, A.Failure == B.Failure, A.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output, D.Failure == E.Failure, D.Output == E.Output {

        public typealias Output = A.Output

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public let d: D

        public let e: E

        let pub: AnyPublisher<A.Output, A.Failure>

        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e

            self.pub = Publishers
                .Sequence(sequence: [
                    a.eraseToAnyPublisher(),
                    b.eraseToAnyPublisher(),
                    c.eraseToAnyPublisher(),
                    d.eraseToAnyPublisher(),
                    e.eraseToAnyPublisher()
                ])
                .flatMap { $0 }
                .eraseToAnyPublisher()
        }

        public func receive<S: Subscriber>(subscriber: S) where E.Failure == S.Failure, E.Output == S.Input {
            self.pub.subscribe(subscriber)
        }

        public func merge<P: Publisher>(with other: P) -> Publishers.Merge6<A, B, C, D, E, P> where E.Failure == P.Failure, E.Output == P.Output {
            return .init(a, b, c, d, e, other)
        }

        public func merge<Z, Y>(with z: Z, _ y: Y) -> Publishers.Merge7<A, B, C, D, E, Z, Y> where Z: Publisher, Y: Publisher, E.Failure == Z.Failure, E.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output {
            return .init(a, b, c, d, e, z, y)
        }

        public func merge<Z, Y, X>(with z: Z, _ y: Y, _ x: X) -> Publishers.Merge8<A, B, C, D, E, Z, Y, X> where Z: Publisher, Y: Publisher, X: Publisher, E.Failure == Z.Failure, E.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output {
            return .init(a, b, c, d, e, z, y, x)
        }
    }

    /// A publisher created by applying the merge function to six upstream publishers.
    public struct Merge6<A, B, C, D, E, F>: Publisher where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, A.Failure == B.Failure, A.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output, D.Failure == E.Failure, D.Output == E.Output, E.Failure == F.Failure, E.Output == F.Output {

        public typealias Output = A.Output

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public let d: D

        public let e: E

        public let f: F

        let pub: AnyPublisher<A.Output, A.Failure>

        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
            self.f = f

            self.pub = Publishers
                .Sequence(sequence: [
                    a.eraseToAnyPublisher(),
                    b.eraseToAnyPublisher(),
                    c.eraseToAnyPublisher(),
                    d.eraseToAnyPublisher(),
                    e.eraseToAnyPublisher(),
                    f.eraseToAnyPublisher()
                ])
                .flatMap { $0 }
                .eraseToAnyPublisher()
        }

        public func receive<S: Subscriber>(subscriber: S) where F.Failure == S.Failure, F.Output == S.Input {
            self.pub.subscribe(subscriber)
        }

        public func merge<P: Publisher>(with other: P) -> Publishers.Merge7<A, B, C, D, E, F, P> where F.Failure == P.Failure, F.Output == P.Output {
            return .init(a, b, c, d, e, f, other)
        }

        public func merge<Z, Y>(with z: Z, _ y: Y) -> Publishers.Merge8<A, B, C, D, E, F, Z, Y> where Z: Publisher, Y: Publisher, F.Failure == Z.Failure, F.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output {
            return .init(a, b, c, d, e, f, z, y)
        }
    }

    /// A publisher created by applying the merge function to seven upstream publishers.
    public struct Merge7<A, B, C, D, E, F, G>: Publisher where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, G: Publisher, A.Failure == B.Failure, A.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output, D.Failure == E.Failure, D.Output == E.Output, E.Failure == F.Failure, E.Output == F.Output, F.Failure == G.Failure, F.Output == G.Output {

        public typealias Output = A.Output

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public let d: D

        public let e: E

        public let f: F

        public let g: G

        let pub: AnyPublisher<A.Output, A.Failure>

        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
            self.f = f
            self.g = g

            self.pub = Publishers
                .Sequence(sequence: [
                    a.eraseToAnyPublisher(),
                    b.eraseToAnyPublisher(),
                    c.eraseToAnyPublisher(),
                    d.eraseToAnyPublisher(),
                    e.eraseToAnyPublisher(),
                    f.eraseToAnyPublisher(),
                    g.eraseToAnyPublisher()
                ])
                .flatMap { $0 }
                .eraseToAnyPublisher()
        }

        public func receive<S: Subscriber>(subscriber: S) where G.Failure == S.Failure, G.Output == S.Input {
            self.pub.subscribe(subscriber)
        }

        public func merge<P: Publisher>(with other: P) -> Publishers.Merge8<A, B, C, D, E, F, G, P> where G.Failure == P.Failure, G.Output == P.Output {
            return .init(a, b, c, d, e, f, g, other)
        }
    }

    /// A publisher created by applying the merge function to eight upstream publishers.
    public struct Merge8<A, B, C, D, E, F, G, H>: Publisher where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, G: Publisher, H: Publisher, A.Failure == B.Failure, A.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output, D.Failure == E.Failure, D.Output == E.Output, E.Failure == F.Failure, E.Output == F.Output, F.Failure == G.Failure, F.Output == G.Output, G.Failure == H.Failure, G.Output == H.Output {

        public typealias Output = A.Output

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public let d: D

        public let e: E

        public let f: F

        public let g: G

        public let h: H

        let pub: AnyPublisher<A.Output, A.Failure>

        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
            self.f = f
            self.g = g
            self.h = h

            self.pub = Publishers
                .Sequence(sequence: [
                    a.eraseToAnyPublisher(),
                    b.eraseToAnyPublisher(),
                    c.eraseToAnyPublisher(),
                    d.eraseToAnyPublisher(),
                    e.eraseToAnyPublisher(),
                    f.eraseToAnyPublisher(),
                    g.eraseToAnyPublisher(),
                    h.eraseToAnyPublisher()
                ])
                .flatMap { $0 }
                .eraseToAnyPublisher()
        }

        public func receive<S: Subscriber>(subscriber: S) where H.Failure == S.Failure, H.Output == S.Input {
            self.pub.subscribe(subscriber)
        }
    }

    public struct MergeMany<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        public let publishers: [Upstream]

        let pub: AnyPublisher<Upstream.Output, Upstream.Failure>

        public init(_ upstream: Upstream...) {
            self.publishers = upstream

            self.pub = Publishers
                .Sequence(sequence: upstream)
                .flatMap { $0 }
                .eraseToAnyPublisher()
        }

        public init<S: Swift.Sequence>(_ upstream: S) where Upstream == S.Element {
            self.publishers = Array(upstream)

            self.pub = Publishers
                .Sequence(sequence: upstream)
                .flatMap { $0 }
                .eraseToAnyPublisher()
        }

        public func receive<S: Subscriber>(subscriber: S) where Upstream.Failure == S.Failure, Upstream.Output == S.Input {

            self.pub.subscribe(subscriber)
        }

        public func merge(with other: Upstream) -> Publishers.MergeMany<Upstream> {
            return .init(Array(self.publishers) + [other])
        }
    }
}
#endif