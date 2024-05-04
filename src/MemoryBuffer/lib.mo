/// The `MemoryBuffer` is an object wrapper around the [BaseMemoryBuffer module](../BaseMemoryBuffer) BaseMemoryBuffer. 
/// It provides a more user-friendly interface opting for methods exposed from the object instead of top-level module functions.
///
/// There are three different modules available for this datastructure:
/// - [Base MemoryBuffer](../Base) - The base module that provides the core functionality for the memory buffer.
/// - [Versioned MemoryBuffer](../Versioned) - The versioned module that supports seamless upgrades without losing data.
/// - MemoryBuffer Class - Class that wraps the versioned module and provides a more user-friendly interface.
///
/// It is recommended to use the MemoryBuffer Class for most use-cases.
///

import Iter "mo:base/Iter";
import Order "mo:base/Order";
import Nat "mo:base/Nat";

import RevIter "mo:itertools/RevIter";

import Blobify "../Blobify";
import BaseMemoryBuffer "Base";
import VersionedMemoryBuffer "Versioned";
import Migrations "Migrations";
import MemoryCmp "../MemoryCmp";

module MemoryBuffer {

    /// ```motoko
    ///     import Blobify "mo:memory-collection/Blobify";
    ///     import MemoryBuffer "mo:memory-collection/MemoryBuffer";
    ///
    ///     stable var sstore = MemoryBuffer.newStableStore<Nat>();
    ///     sstore := MemoryBuffer.upgrade(sstore);
    ///     
    ///     let buffer = MemoryBuffer.MemoryBuffer<Nat>(sstore, Blobify.BigEndian.Nat);
    ///
    ///     buffer.add(0);
    ///     buffer.add(1);
    ///     assert buffer.size() == 2;
    ///
    ///     assert buffer.get(0) == 0;
    ///     assert buffer.remove(1) == 1;
    ///
    ///     buffer.put(0, 2);
    ///     assert buffer.get(0) == 2;
    ///
    /// ```
    ///
    /// More details about the memory layout of the buffer can be found in the [BaseMemoryBuffer module](../BaseMemoryBuffer).
    ///
    /// > **`Note:`** If you are upgrading to newer versions of the memory collection library, ensure that you call the 
    /// `upgrade()` function to migrate the data to the latest version.

    type Iter<A> = Iter.Iter<A>;
    type RevIter<A> = RevIter.RevIter<A>;
    type Order = Order.Order;
    type Blobify<A> = Blobify.Blobify<A>;

    public type BaseMemoryBuffer<A> = Migrations.MemoryBuffer<A>;
    public type VersionedMemoryBuffer<A> = Migrations.VersionedMemoryBuffer<A>;

    /// Creates a new stable store for the memory buffer.
    public func newStableStore<A>() : VersionedMemoryBuffer<A> = VersionedMemoryBuffer.new();

    /// Upgrades the memory buffer to the latest version.
    public func upgrade<A>(versions : VersionedMemoryBuffer<A>) : VersionedMemoryBuffer<A> {
        Migrations.upgrade<A>(versions);
    };

    public class MemoryBuffer<A>(versions : VersionedMemoryBuffer<A>, blobify : Blobify<A>) {
        let internal = Migrations.getCurrentVersion(versions);

        /// Adds an element to the end of the buffer.
        public func add(elem: A) = BaseMemoryBuffer.add<A>(internal, blobify, elem);

        /// Returns the element at the given index.
        public func get(i: Nat) : A = BaseMemoryBuffer.get<A>(internal, blobify, i);

        /// Returns the number of elements in the buffer.
        public func size() : Nat = BaseMemoryBuffer.size<A>(internal);

        /// Returns the number of bytes used to store the serialized elements in the buffer.
        public func bytes() : Nat = BaseMemoryBuffer.bytes<A>(internal);

        /// Returns the number of bytes used to store the metadata and memory block pointers.
        public func metadataBytes() : Nat = BaseMemoryBuffer.metadataBytes<A>(internal);

        /// Returns the number of elements the buffer can hold before resizing.
        public func capacity() : Nat = BaseMemoryBuffer.capacity<A>(internal);
        
        /// Overwrites the element at the given index with the new element.
        public func put(i: Nat, elem: A) = BaseMemoryBuffer.put<A>(internal, blobify, i, elem);
        
        /// Returns the element at the given index or `null` if the index is out of bounds.
        public func getOpt(i: Nat) : ?A = BaseMemoryBuffer.getOpt<A>(internal, blobify, i);

        /// Adds an element before the first element in the buffer.
        /// Runtime: `O(1)`
        public func addFirst(elem: A) = BaseMemoryBuffer.addFirst<A>(internal, blobify, elem);

        /// Adds an element after the last element in the buffer. Alias for `add()`.
        /// Runtime: `O(1)`
        public func addLast(elem: A) = BaseMemoryBuffer.addLast<A>(internal, blobify, elem);

        /// Adds all elements from the given iterator to the end of the buffer.
        public func addFromIter(iter: Iter<A>) = BaseMemoryBuffer.addFromIter<A>(internal, blobify, iter);

        /// Adds all elements from the given array to the end of the buffer.
        public func addFromArray(arr: [A]) = BaseMemoryBuffer.addFromArray<A>(internal, blobify, arr);

        /// Returns a reversable iterator over the elements in the buffer.
        /// 
        /// ```motoko
        ///     stable var sstore = MemoryBuffer.newStableStore<Text>();
        ///     sstore := MemoryBuffer.upgrade(sstore);
        ///     
        ///     let buffer = MemoryBuffer.MemoryBuffer<Text>(sstore, Blobify.Text);
        ///
        ///     buffer.addFromArray(["a", "b", "c"]);
        ///
        ///     let vals = Iter.toArray(buffer.vals());
        ///     assert vals == ["a", "b", "c"];
        ///
        ///     let reversed = Iter.toArray(buffer.vals().rev());
        ///     assert reversed == ["c", "b", "a"];
        /// ```
        public func vals() : RevIter<A> = BaseMemoryBuffer.vals<A>(internal, blobify);

        /// Returns a reversable iterator over a tuple of the index and element in the buffer.
        public func items() : RevIter<(Nat, A)> = BaseMemoryBuffer.items<A>(internal, blobify);

        /// Returns a reversable iterator over the serialized elements in the buffer.
        public func blobs() : RevIter<Blob> = BaseMemoryBuffer.blobs<A>(internal);

        /// Swaps the elements at the given indices.
        public func swap(i: Nat, j: Nat) = BaseMemoryBuffer.swap<A>(internal, i, j);

        /// Swaps the element at the given index with the last element in the buffer and removes it.
        public func swapRemove(i: Nat) : A = BaseMemoryBuffer.swapRemove<A>(internal, blobify, i);

        /// Removes the element at the given index.
        public func remove(i: Nat) : A = BaseMemoryBuffer.remove<A>(internal, blobify, i);

        /// Removes the first element in the buffer.
        ///
        /// ```motoko
        ///     stable var sstore = MemoryBuffer.newStableStore<Text>();
        ///     sstore := MemoryBuffer.upgrade(sstore);
        ///     
        ///     let buffer = MemoryBuffer.MemoryBuffer<Nat>(sstore, Blobify.Nat); // little-endian
        ///
        ///     buffer.addFromArray([1, 2, 3]);
        ///
        ///     assert buffer.removeFirst() == ?1;
        /// ```
        public func removeFirst() : ?A = BaseMemoryBuffer.removeFirst<A>(internal, blobify);

        /// Removes the last element in the buffer.
        public func removeLast() : ?A = BaseMemoryBuffer.removeLast<A>(internal, blobify);

        /// Inserts an element at the given index.
        public func insert(i: Nat, elem: A) = BaseMemoryBuffer.insert<A>(internal, blobify, i, elem);

        /// Sorts the elements in the buffer using the given comparison function.
        /// This function implements quicksort, an unstable sorting algorithm with an average time complexity of `O(n log n)`.
        /// It also supports a comparision function that can either compare the elements the default type or in their serialized form as blobs.
        /// For more information on the comparison function, refer to the [MemoryCmp module](../MemoryCmp).
        public func sortUnstable(cmp: MemoryCmp.MemoryCmp<A> ) = BaseMemoryBuffer.sortUnstable<A>(internal, blobify, cmp);

        /// Randomly shuffles the elements in the buffer.
        public func shuffle() = BaseMemoryBuffer.shuffle<A>(internal);

        /// Reverse the order of the elements in the buffer.
        public func reverse() = BaseMemoryBuffer.reverse<A>(internal);

        /// Returns the index of the first element that is equal to the given element.
        public func indexOf(equal: (A, A) -> Bool, elem: A) : ?Nat = BaseMemoryBuffer.indexOf<A>(internal, blobify, equal, elem);

        /// Returns the index of the last element that is equal to the given element.
        public func lastIndexOf(equal: (A, A) -> Bool, elem: A) : ?Nat = BaseMemoryBuffer.lastIndexOf<A>(internal, blobify, equal, elem);

        /// Returns `true` if the buffer contains the given element.
        public func contains(equal: (A, A) -> Bool, elem: A) : Bool = BaseMemoryBuffer.contains<A>(internal, blobify, equal, elem);

        /// Returns `true` if the buffer is empty.
        public func isEmpty() : Bool = BaseMemoryBuffer.isEmpty<A>(internal);

        /// Returns the first element in the buffer. Traps if the buffer is empty.
        public func first() : A = BaseMemoryBuffer.first<A>(internal, blobify);

        /// Returns the last element in the buffer. Traps if the buffer is empty.
        public func last() : A = BaseMemoryBuffer.last<A>(internal, blobify);

        /// Returns the first element in the buffer or `null` if the buffer is empty.
        public func peekFirst() : ?A = BaseMemoryBuffer.peekFirst<A>(internal, blobify);

        /// Returns the last element in the buffer or `null` if the buffer is empty.
        public func peekLast() : ?A = BaseMemoryBuffer.peekLast<A>(internal, blobify);
        
        /// Removes all elements from the buffer.
        public func clear() = BaseMemoryBuffer.clear<A>(internal);

        /// Copies all the elements in the buffer to a new array.
        public func toArray() : [A] = BaseMemoryBuffer.toArray<A>(internal, blobify);

        public func _getInternalRegion() : BaseMemoryBuffer<A> = internal;
        public func _getBlobifyFn() : Blobify<A> = blobify;
    };

    // public func init<A>(internal: VersionedMemoryBuffer<A>, blobify: Blobify<A>, size: Nat, val: A) : MemoryBuffer<A> {
    //     let mbuffer = MemoryBuffer(internal, blobify);

    //     for (_ in Iter.range(0, size - 1)){
    //         mbuffer.add(val);
    //     };

    //     return mbuffer;
    // };

    // public func tabulate<A>(internal: VersionedMemoryBuffer<A>, blobify: Blobify<A>, size: Nat, f: (Nat) -> A) : MemoryBuffer<A> {
    //     BaseMemoryBuffer.tabulate(internal, blobify, size, f);
    //     return MemoryBuffer(internal, blobify);
    // };

    // public func fromArray<A>(internal: VersionedMemoryBuffer<A>, blobify: Blobify<A>, arr: [A]) : MemoryBuffer<A> {
    //     BaseMemoryBuffer.fromArray(internal, blobify, arr);
    //     return MemoryBuffer(internal, blobify);
    // };

    public func toArray<A>(mbuffer: MemoryBuffer<A>) : [A] {
        return BaseMemoryBuffer.toArray(mbuffer._getInternalRegion(), mbuffer._getBlobifyFn());
    };

}