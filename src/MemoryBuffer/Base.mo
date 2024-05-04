/// This is the base implementation of a persistent buffer that stores its values in stable memory.
/// The buffer employs two memory regions to store the values and the pointers to the memory blocks where the values are stored.
/// The buffer grows by a factor of `√(P)`, where `P` is the total number of pages previously allocated.
/// 
/// In addition to the expected buffer functions, the buffer add or remove values from either ends of the buffer in O(1) time.
/// 
///
/// # Memory Region Layout
/// 
/// ## Value Blob Region
/// This region stores the serialized values in the buffer.
///
/// |           Field          | Offset | Size |  Type  | Value |                                Description                              |
/// |--------------------------|--------|------|--------|-------|-------------------------------------------------------------------------|
/// | Magic Number             |  0     |  3   | Blob   | "BLB" | Magic Number used to identify the Blob Region                           |
/// | Layout Version           |  3     |  1   | Nat8   | 0     | Layout Version detailing how the data in the region is structured       |
/// | Buffer Metadata Region   |  4     |  4   | Nat32  | -     | Region Id of the Buffer Metadata Region that it is attached to                 |
/// | Reserved Header Space    |  8     |  56  | -      | -     | Reserved Space for future use if the layout needs to be updated         |
/// | Value * `N`              |  64    |  -   | Blob   | -     | N number of arbitrary sized values, serialized and stored in the region |
/// 
/// ## Buffer Metadata Region
/// This region stores the metadata and pointers to the Blob Region.
///
/// |           Field          | Offset |   Size    |     Type      |  Value  |                                Description                              |
/// |--------------------------|--------|-----------|---------------|---------|-------------------------------------------------------------------------|
/// | Magic Number             |  0     |  3        | Blob          | "BLB"   | Magic Number for identifying the Buffer Region                          |
/// | Layout Version           |  3     |  1        | Nat8          | 0 or 1  | Layout Version detailing how the data in the region is structured       |
/// | Blob Region ID           |  4     |  4        | Nat32         | -       | Region Id of the Blob Region attached to itself                         |
/// | Count                    |  8     |  8        | Nat64         | -       | Number of elements stored in the buffer                                 |
/// | Start Index              |  16    |  8        | Nat64         | -       | Internal index where the first value is stored in the buffer            |
/// | Prev Pages Allocated     |  24    |  4        | Nat32         | -       | Number of pages allocated during the resize operation                   |
/// | Extra Header Space       |  28    |  36       | -             | -       | Reserved Space for future use if the layout needs to be updated         |
/// | Pointer * `N`            |  64    |  12 * `N` | Nat64 # Nat32 | -       | Pointers to the memory blocks in the Blob Region. It stores the concatenated memory block offset (8 bytes) and size (4 bytes) |
///


import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Order "mo:base/Order";

import MemoryRegion "mo:memory-region/MemoryRegion";
import RevIter "mo:itertools/RevIter";
import Itertools "mo:itertools/Iter";

import Blobify "../Blobify";
import Migrations "Migrations";
import MemoryCmp "../MemoryCmp";

module MemoryBuffer {


    type Iter<A> = Iter.Iter<A>;
    type RevIter<A> = RevIter.RevIter<A>;
    type Result<A, B> = Result.Result<A, B>;
    type MemoryRegion = MemoryRegion.MemoryRegion;
    type Order = Order.Order;

    public type MemoryBufferRegion = {
        pointers : MemoryRegion;
        blobs : MemoryRegion;
    };

    public type MemoryBuffer<A> = Migrations.MemoryBuffer<A>;
    public type VersionedMemoryBuffer<A> = Migrations.VersionedMemoryBuffer<A>;

    public let REGION_HEADER_SIZE = 64;

    public let POINTER_SIZE = 12;
    public let LAYOUT_VERSION = 0;

    let C = Migrations.Layout.1;

    /// The Blobify typeclass is used to serialize and deserialize values.
    public type Blobify<A> = Blobify.Blobify<A>;

    /// Creates a new memory buffer.
    public func new<A>() : MemoryBuffer<A> {
        let memory_region = {
            pointers = MemoryRegion.new();
            blobs = MemoryRegion.new();
            var count = 0;
            var start = 0;
            var prev_pages_allocated = 0;
        };

        init_region_header(memory_region);

        memory_region;
    };

    
    func init_region_header<A>(m_region : MemoryBuffer<A>) {
        assert MemoryRegion.size(m_region.blobs) == 0;
        assert MemoryRegion.size(m_region.pointers) == 0;

        // Each Region has a 64 byte header
        ignore MemoryRegion.allocate(m_region.blobs, REGION_HEADER_SIZE); // Reserved Space for the Region Header
        MemoryRegion.storeBlob(m_region.blobs, C.MAGIC_NUMBER_ADDRESS, "BLB"); // MAGIC NUMBER (BLB -> Blob Region) 3 bytes
        MemoryRegion.storeNat8(m_region.blobs, C.LAYOUT_VERSION_ADDRESS, Nat8.fromNat(LAYOUT_VERSION)); // |1 byte | Layout Version (1)
        MemoryRegion.storeNat32(m_region.blobs, C.REGION_ID_ADDRESS, Nat32.fromNat(MemoryRegion.id(m_region.pointers))); // store the pointers region id in the blob region
        assert MemoryRegion.size(m_region.blobs) == REGION_HEADER_SIZE;

        // | 64 byte header | -> 3 bytes + 1 byte + 8 bytes + 52 bytes
        ignore MemoryRegion.allocate(m_region.pointers, REGION_HEADER_SIZE); // Reserved Space for the Region Header
        MemoryRegion.storeBlob(m_region.pointers, C.MAGIC_NUMBER_ADDRESS, "BFR"); // |3 bytes| MAGIC NUMBER (BFR -> Buffer Region)
        MemoryRegion.storeNat8(m_region.pointers, C.LAYOUT_VERSION_ADDRESS, Nat8.fromNat(LAYOUT_VERSION)); // |1 byte | Layout Version (1)
        MemoryRegion.storeNat32(m_region.pointers, C.REGION_ID_ADDRESS, Nat32.fromNat(MemoryRegion.id(m_region.blobs))); // store the blobs region id in the pointers region
        MemoryRegion.storeNat64(m_region.pointers, C.COUNT_ADDRESS, 0); // |8 bytes| Count -> Number of elements in the buffer
        MemoryRegion.storeNat64(m_region.pointers, C.START_ADDRESS, 0); // |8 bytes| Start Address -> Start of the pointers region
        MemoryRegion.storeNat32(m_region.pointers, C.PREV_PAGES_ALLOCATED_START, 0); // |4 bytes| Number of pages to allocate when growing the buffer. Increments by 1 each time the buffer grows.
        assert MemoryRegion.size(m_region.pointers) == REGION_HEADER_SIZE;
    };

    func update_count<A>(self : MemoryBuffer<A>, count : Nat) {
        self.count := count;
        MemoryRegion.storeNat64(self.pointers, C.COUNT_ADDRESS, Nat64.fromNat(count));
    };

    func update_start<A>(self: MemoryBuffer<A>, start: Nat) {
        self.start := start;
        MemoryRegion.storeNat64(self.pointers, C.START_ADDRESS, Nat64.fromNat(start));
    };

    func update_prev_pages_allocated<A>(self: MemoryBuffer<A>, pages: Nat) {
        self.prev_pages_allocated := pages;
        MemoryRegion.storeNat32(self.pointers, C.PREV_PAGES_ALLOCATED_START, Nat32.fromNat(pages));
    };

    public func verify(region : MemoryBufferRegion) : Result<(), Text> {
        if (MemoryRegion.loadBlob(region.blobs, C.MAGIC_NUMBER_ADDRESS, 3) != "BLB") {
            return #err("Invalid Blob Region Magic Number");
        };

        if (Nat32.toNat(MemoryRegion.loadNat32(region.blobs, C.REGION_ID_ADDRESS)) != MemoryRegion.id(region.pointers)) {
            return #err("Invalid Blob Region ID");
        };

        if (MemoryRegion.loadBlob(region.pointers, C.MAGIC_NUMBER_ADDRESS, 3) != "BFR") {
            return #err("Invalid Buffer Region Magic Number");
        };

        if (Nat32.toNat(MemoryRegion.loadNat32(region.pointers, C.REGION_ID_ADDRESS)) != MemoryRegion.id(region.blobs)) {
            return #err("Invalid Buffer Region ID");
        };

        #ok(());
    };

    /// Converts from a versioned memory buffer
    public func fromVersioned<A>(self : VersionedMemoryBuffer<A>) : MemoryBuffer<A> {
        Migrations.getCurrentVersion(self);
    };

    /// Converts the memory buffer to a versioned one.
    public func toVersioned<A>(self : MemoryBuffer<A>) : VersionedMemoryBuffer<A> {
        #v0(self);
    };

    /// Initializes a memory buffer with a given value and size.
    public func init<A>(blobify : Blobify<A>, size : Nat, val : A) : MemoryBuffer<A> {
        let mbuffer = MemoryBuffer.new<A>();

        for (_ in Iter.range(1, size - 1)) {
            MemoryBuffer.add(mbuffer, blobify, val);
        };

        mbuffer;
    };

    /// Initializes a memory buffer with a given function and size.
    public func tabulate<A>(blobify : Blobify<A>, size : Nat, fn : (i : Nat) -> A) : MemoryBuffer<A> {
        let mbuffer = MemoryBuffer.new<A>();

        for (i in Iter.range(0, size - 1)) {
            MemoryBuffer.add(mbuffer, blobify, fn(i));
        };

        mbuffer;
    };

    /// Initializes a memory buffer with a given array.
    public func fromArray<A>(blobify : Blobify<A>, arr : [A]) : MemoryBuffer<A> {
        let mbuffer = MemoryBuffer.new<A>();

        for (elem in arr.vals()) {
            add(mbuffer, blobify, elem);
        };

        mbuffer;
    };

    public func fromIter<A>(blobify : Blobify<A>, iter : Iter<A>) : MemoryBuffer<A> {
        let mbuffer = MemoryBuffer.new<A>();

        for (elem in iter) {
            add(mbuffer, blobify, elem);
        };

        mbuffer;
    };

    /// Returns the number of elements in the buffer.
    public func size<A>(self : MemoryBuffer<A>) : Nat {
        return self.count;
    };

    /// Returns the number of bytes used for storing the values in the buffer.
    public func bytes<A>(self : MemoryBuffer<A>) : Nat {
        return MemoryRegion.allocated(self.blobs);
    };

    /// Returns the bytes used for storing the metadata which include the pointers, buffer size, and region headers.
    public func metadataBytes<A>(self : MemoryBuffer<A>) : Nat {
        return (self.count * 12) + (REGION_HEADER_SIZE)
    };

    public func totalBytes<A>(self : MemoryBuffer<A>) : Nat {
        return bytes(self) + metadataBytes(self);
    };

    /// Returns the number of elements that can be stored in the buffer before it needs to grow.
    public func capacity<A>(self : MemoryBuffer<A>) : Nat {
        return (MemoryRegion.capacity(self.pointers) - REGION_HEADER_SIZE) / POINTER_SIZE;
    };

    public func _get_pointer<A>(_ : MemoryBuffer<A>, index : Nat) : Nat {
        C.POINTERS_START + (index * POINTER_SIZE);
    };

    func buffer_capacity<A>(self: MemoryBuffer<A>): Nat {
        (MemoryRegion.capacity(self.pointers) - REGION_HEADER_SIZE) / POINTER_SIZE; 
    };

    /// Returns the internal index where the value at the given index is stored.
    public func get_circular_index<A>(self : MemoryBuffer<A>, index : Int) : Nat {
        Int.abs((self.start + index ) % buffer_capacity(self));
    };

    func grow_if_needed<A>(self: MemoryBuffer<A>) {
        if (self.count < buffer_capacity(self)) return;

        let pages_to_allocate = self.prev_pages_allocated + 1;
        ignore MemoryRegion.grow(self.pointers, pages_to_allocate);

        let new_page_bytes = (pages_to_allocate * MemoryRegion.PageSize) / POINTER_SIZE;
        ignore MemoryRegion.allocate(self.pointers, new_page_bytes);

        update_prev_pages_allocated(self, pages_to_allocate);

        let new_capacity = buffer_capacity(self);

        let elems_before_start = self.start;
        let elems_after_start = self.count - elems_before_start;

        if (elems_before_start < elems_after_start) {
            var i = 0;

            while (i < elems_before_start){
                swap(self, i, self.count + i);
                i += 1;
            };
        } else {
            var i = 0;

            while (i < elems_after_start){
                swap(self, self.count - i - 1, new_capacity - i - 1);
                i += 1;
            };

            update_start(self, new_capacity - elems_after_start);
        };
    };

    func _get_memory_blob<A>(self : MemoryBuffer<A>, index : Nat) : Blob {
        let ptr_address = _get_pointer(self, index);
        MemoryRegion.loadBlob(self.pointers, ptr_address, POINTER_SIZE);
    };

    public func _get_memory_address<A>(self : MemoryBuffer<A>, index : Nat) : Nat {
        let pointer_address = _get_pointer(self, index);
        let address = MemoryRegion.loadNat64(self.pointers, pointer_address);
        Nat64.toNat(address);
    };

    public func _get_memory_size<A>(self : MemoryBuffer<A>, index : Nat) : Nat {
        let pointer_address = _get_pointer(self, index);
        let value_size = MemoryRegion.loadNat32(self.pointers, pointer_address + 8);

        Nat32.toNat(value_size);
    };

    func update_pointer_at_index<A>(self : MemoryBuffer<A>, index : Nat, mb_address : Nat, mb_size : Nat) {
        let pointer_address = _get_pointer(self, index);
        MemoryRegion.storeNat64(self.pointers, pointer_address, Nat64.fromNat(mb_address));
        MemoryRegion.storeNat32(self.pointers, pointer_address + 8, Nat32.fromNat(mb_size));
    };

    func add_pointer<A>(self : MemoryBuffer<A>, mb_address : Nat, mb_size : Nat) {
        grow_if_needed(self);

        let i = get_circular_index(self, self.count);
        let pointer_address = _get_pointer(self, i);

        MemoryRegion.storeNat64(self.pointers, pointer_address, Nat64.fromNat(mb_address));
        MemoryRegion.storeNat32(self.pointers, pointer_address + 8, Nat32.fromNat(mb_size));
    };

    func internal_replace<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat, new_value : A) {
        let mb_address = _get_memory_address(self, index);
        let mb_size = _get_memory_size(self, index);

        let new_blob = blobify.to_blob(new_value);
        let new_size = new_blob.size();

        let new_address = MemoryRegion.resize(self.blobs, mb_address, mb_size, new_size);
        // if (mb_size == new_size) assert new_address == mb_address;
        if (mb_size != new_size) update_pointer_at_index(self, index, new_address, new_size);

        MemoryRegion.storeBlob(self.blobs, new_address, new_blob);
    };

    /// Adds a value to the end of the buffer.
    public func add<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, value : A) {
        let blob = blobify.to_blob(value);
        let mb_address = MemoryRegion.addBlob(self.blobs, blob);

        // Debug.print("Value added to mem-block at address = " # debug_show mb_address);
        grow_if_needed(self);
        
        let i = get_circular_index(self, self.count);
        update_pointer_at_index(self, i, mb_address, blob.size());
        update_count(self, self.count + 1);
    };

    /// Adds all the values from the given array to the end of the buffer.
    public func addFromArray<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, values : [A]) {
        for (val in values.vals()) {
            add(self, blobify, val);
        };
    };

    /// Adds all the values from the given iterator to the end of the buffer.
    public func addFromIter<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, iter : Iter<A>) {
        for (val in iter) {
            add(self, blobify, val);
        };
    };

    /// Adds a value to the beginning of the buffer.
    public func addFirst<A>(self: MemoryBuffer<A>, blobify: Blobify<A>, value: A) {
        let blob = blobify.to_blob(value);
        let mb_address = MemoryRegion.addBlob(self.blobs, blob);

        grow_if_needed(self);

        let i = get_circular_index(self, -1);
        update_pointer_at_index(self, i, mb_address, blob.size());
        update_start(self, i);
        update_count(self, self.count + 1);
    };

    /// Adds a value to the end of the buffer.
    public func addLast<A>(self: MemoryBuffer<A>, blobify: Blobify<A>, value: A) {
        add(self, blobify, value);
    };  

    /// Replaces the value at the given index with the given value.
    public func put<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat, value : A) {
        if (index >= self.count) {
            Debug.trap("MemoryBuffer put(): Index out of bounds");
        };

        let i = get_circular_index(self, index);
        internal_replace(self, blobify, i, value);
    };

    /// Retrieves the value at the given index if it exists. Otherwise returns null.
    public func getOpt<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : ?A {
        if (index >= self.count) {
            return null;
        };

        let value = get(self, blobify, index);

        return ?value;
    };

    public func _get_blob<A>(self : MemoryBuffer<A>, index : Nat) : Blob {
        let address = _get_memory_address(self, index);
        let size = _get_memory_size(self, index);
        let blob = MemoryRegion.loadBlob(self.blobs, address, size);
        blob;
    };

    func _get<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : A {
        let i = get_circular_index(self, index);
        let blob = _get_blob(self, i);
        let val = blobify.from_blob(blob);
        val
    };

    /// Retrieves the value at the given index. Traps if the index is out of bounds.
    public func get<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : A {
        if (index >= self.count) {
            Debug.trap("MemoryBuffer get(): Index out of bounds");
        };

        _get(self, blobify, index);
    };

    public func _get_memory_block<A>(self : MemoryBuffer<A>, index : Nat) : (Nat, Nat) {
        let address = _get_memory_address(self, index);
        let size = _get_memory_size(self, index);
        (address, size);
    };

    /// Adds all the values from the given buffer to the end of this buffer.
    public func append<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, other : MemoryBuffer<A>) {
        switch (verify(other)) {
            case (#ok(_)) {};
            case (#err(err)) Debug.trap("MemoryBuffer append(): " # err);
        };

        for (value in vals(other, blobify)) {
            add(self, blobify, value);
        };
    };

    /// Adds all the values from the given array to the end of this buffer.
    public func appendArray<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, blobs : [A]) {
        for (value in blobs.vals()) {
            add(self, blobify, value);
        };
    };

    /// Adds all the values from the given buffer to the end of this buffer.
    public func appendBuffer<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, other : { vals : () -> Iter<A> }) {
        for (value in other.vals()) {
            add(self, blobify, value);
        };
    };

    public func keys<A>(self : MemoryBuffer<A>) : RevIter<Nat> {
        RevIter.range(0, self.count);
    };

    /// Returns an iterator over the values in the buffer.
    public func vals<A>(self : MemoryBuffer<A>, blobify : Blobify<A>) : RevIter<A> {
        return range(self, blobify, 0, self.count);
    };

    /// Returns an iterator over the values in the given range.
    ///
    /// ```motoko
    ///     let buffer = MemoryBuffer.fromArray(Blobify.int, [1, 2, 3, 4, 5]);
    ///     let iter = MemoryBuffer.range(Blobify.int, 1, 3);
    ///     assert Iter.toArray(iter) == [2, 3];
    /// ```
    public func range<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, start : Nat, end : Nat) : RevIter<A> {
        var i = start;
        var j = end;

        func next() : ?A {
            if (i >= j) {
                return null;
            };

            let val = _get(self, blobify, i);
            i += 1;
            ?val;
        };

        func nextFromEnd() : ?A {
            if (i >= j) {
                return null;
            };

            let val = _get(self, blobify, j - 1 : Nat);
            j -= 1;
            ?val;
        };

        return RevIter.new(next, nextFromEnd);
    };

    /// Return an iterator over the indices and values in the buffer.
    public func items<A>(self : MemoryBuffer<A>, blobify : Blobify<A>) : RevIter<(index : Nat, value : A)> {
        itemsRange(self, blobify, 0, self.count);
    };

    public func itemsRange<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, start : Nat, end : Nat) : RevIter<(index : Nat, value : A)> {
        var i = start;
        var j = end;

        func next() : ?(Nat, A) {
            if (i >= j) {
                return null;
            };

            let index = i;
            let val = _get(self, blobify, index);
            i += 1;
            ?(index, val);
        };

        func nextFromEnd() : ?(Nat, A) {
            if (i >= j) {
                return null;
            };

            let index = j - 1 : Nat;
            let val = _get(self, blobify, index);
            j -= 1;
            ?(index, val);
        };

        RevIter.new(next, nextFromEnd);
    };

    /// An iterator over the serialized blobs in the buffer.
    public func blobs<A>(self : MemoryBuffer<A>) : RevIter<Blob> {
        var i = 0;
        var j = self.count;

        func next() : ?Blob {
            if (i >= j) {
                return null;
            };

            let blob = _get_blob(self, i);
            i += 1;
            ?blob;
        };

        func nextFromEnd() : ?Blob {
            if (i >= j) {
                return null;
            };

            let blob = _get_blob(self, j - 1 : Nat);
            j -= 1;
            ?blob;
        };

        return RevIter.new(next, nextFromEnd);
    };

    /// An iterator over the pointers to the memory blocks where the serialized values are stored.
    /// The iterator returns the address of the pointer because the size of each pointer is fixed at 12 bytes.
    public func pointers<A>(self: MemoryBuffer<A>) : RevIter<Nat> {
        var i = 0;
        var j = self.count;

        func next() : ?Nat {
            if (i >= j) {
                return null;
            };

            let _index = get_circular_index(self, i);
            let address = _get_pointer(self, _index);
            i += 1;
            ?address;
        };

        func nextFromEnd() : ?Nat {
            if (i >= j) {
                return null;
            };

            let _index = get_circular_index(self, j - 1);
            let address = _get_pointer(self, _index : Nat);
            j -= 1;
            ?address;
        };

        return RevIter.new(next, nextFromEnd);
    };

    /// An iterator over the memory blocks where the serialized values are stored.
    public func blocks<A>(self : MemoryBuffer<A>) : RevIter<(Nat, Nat)> {
        var i = 0;
        var j = self.count;

        func next() : ?(Nat, Nat) {
            if (i >= j) {
                return null;
            };

            let _index = get_circular_index(self, i);
            let address = _get_memory_address(self, _index);
            let size = _get_memory_size(self, _index);

            i += 1;
            ?(address, size);
        };

        func nextFromEnd() : ?(Nat, Nat) {
            if (i >= j) {
                return null;
            };

            let _index = get_circular_index(self, j - 1);
            let address = _get_memory_address(self, _index);
            let size = _get_memory_size(self, _index);
            j -= 1;
            ?(address, size);
        };

        return RevIter.new(next, nextFromEnd);
    };

    func shift_pointers<A>(self : MemoryBuffer<A>, start : Nat, end : Nat, n : Int) {
        let start_address = _get_pointer(self, start);
        if (end <= start ) return;
        let size = (end - start : Nat) * POINTER_SIZE;

        let pointers_blob = MemoryRegion.loadBlob(self.pointers, start_address, size);

        let new_index = Int.abs(start + n);

        let new_address = _get_pointer(self, new_index);

        MemoryRegion.storeBlob(self.pointers, new_address, pointers_blob);
        // let empty_blob = Blob.fromArray(
        //     Array.tabulate<Nat8>(Int.abs(n) * POINTER_SIZE, func(_: Nat) : Nat8 = 0 )
        // );
        // MemoryRegion.storeBlob(self.pointers, new_address + pointers_blob.size(), empty_blob);
    };

    func remove_blob<A>(self : MemoryBuffer<A>, index : Nat) : Blob {
        // Debug.print("Retrieving memory block");
        let mb_address = _get_memory_address(self, index);
        let mb_size = _get_memory_size(self, index);

        // Debug.print("Removing Blob");
        let blob = MemoryRegion.removeBlob(self.blobs, mb_address, mb_size);
        blob;
    };

    func remove_val<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : A {
        let blob = remove_blob(self, index);
        // Debug.print("Removed blob");
        blobify.from_blob(blob);
    };

    /// Removes the value at the given index. Traps if the index is out of bounds.
    public func remove<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : A {
        if (index >= self.count) {
            Debug.trap("MemoryBuffer remove(): Index out of bounds");
        };

        // Debug.print("Removing value at index = " # debug_show index);
        let i = get_circular_index(self, index);
        let value = remove_val(self, blobify, i);

        let shift_left = index >= self.count / 2;
        if (shift_left) {
            // Debug.print("Shifting pointers left");

            let end = get_circular_index(self, self.count);

            if (end < i) { // the buffer is wrapped
                shift_pointers(self, i + 1, buffer_capacity(self), -1);
                swap(self, buffer_capacity(self) - 1, 0);
                shift_pointers(self, 1, end, -1);
            } else {    
                shift_pointers(self, i + 1, end, -1);
            };

        } else {
            // Debug.print("Shifting pointers right");

            let start = self.start;

            if (i < start) { // the buffer is wrapped
                shift_pointers(self, 0, i, 1);
                swap(self, 0, buffer_capacity(self) - 1);
                shift_pointers(self, start, buffer_capacity(self), 1);
            } else {
                shift_pointers(self, start, i, 1);
            };

            update_start(self, get_circular_index(self, 1));
        };

        update_count(self, self.count - 1 : Nat);

        return value;
    };

    // public func removeBatch<A>(self: MemoryBuffer<A>, blobify: Blobify<A>, index: Nat, batch_size: Nat) : RevIter<A> {
        
    //     if (index + batch_size > self.count or index == self.count) {
    //         Debug.trap("MemoryBuffer removeBatch(): Index out of bounds");
    //     };

    //     let removed_values = Array.tabulate(batch_size, func(i: Nat) : A {
    //         remove_val(self, blobify, index);
    //     });

    //     shift_pointers(self, index + batch_size, self.count, -batch_size);
    //     update_count(self, self.count - batch_size);

    //     return RevIter.fromArray(removed_values);
    // };

    public func removeFirst<A>(self: MemoryBuffer<A>, blobify: Blobify<A>) :?A {
        if (self.count == 0) return null;
        
        let value = remove_val(self, blobify, 0);

        update_count(self, self.count - 1);
        update_start(self, get_circular_index(self, 1));

        ?value;
    };

    /// Removes the last value in the buffer, if it exists. Otherwise returns null.
    public func removeLast<A>(self : MemoryBuffer<A>, blobify : Blobify<A>) : ?A {
        if (self.count == 0) return null;

        let i = get_circular_index(self, self.count - 1);
        let value = remove_val(self, blobify, i);

        update_count(self, self.count - 1);
        ?value
    };

    /// Inserts a value at the given index.
    public func insert<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat, value : A) {

        if (index > self.count) {
            Debug.trap("MemoryBuffer: Index out of bounds");
        };

        grow_if_needed(self);

        var i = get_circular_index(self, index);

        let shift_right = i >= self.count / 2;

        if (shift_right and self.count > 0) {
            let end = get_circular_index(self, self.count);

            if (end < i) {
                shift_pointers(self, 0, end, 1);
                swap(self, 0, buffer_capacity(self) - 1);
                shift_pointers(self, i, buffer_capacity(self) - 1, 1);
            } else {
                shift_pointers(self, i, end, 1);
            };

        } else if (self.count > 0){
            let start = self.start;

            if (i < start) {
                let end = get_circular_index(self, self.count);
                shift_pointers(self, start, buffer_capacity(self), -1);
                swap(self, 0, buffer_capacity(self) - 1);

                shift_pointers(self, 1, end, 1);
            } else {
                shift_pointers(self, start, i, -1);
            };

            update_start(self, get_circular_index(self, -1));
            i := get_circular_index(self, index);
        };

        let blob = blobify.to_blob(value);
        assert blob.size() > 0;

        let mb_address = MemoryRegion.addBlob(self.blobs, blob);

        update_pointer_at_index(self, i, mb_address, blob.size());

        update_count(self, self.count + 1);
    };

    /// Swaps the values at the given indices.
    public func swap<A>(self : MemoryBuffer<A>, index_a : Nat, index_b : Nat) {
        let _index_a = get_circular_index(self, index_a);
        let _index_b = get_circular_index(self, index_b);

        let mem_block_a = _get_memory_blob(self, _index_a);
        let mem_block_b = _get_memory_blob(self, _index_b);

        let ptr_addr_a = _get_pointer(self, _index_a);
        let ptr_addr_b = _get_pointer(self, _index_b);

        MemoryRegion.storeBlob(self.pointers, ptr_addr_a, mem_block_b);
        MemoryRegion.storeBlob(self.pointers, ptr_addr_b, mem_block_a);
    };

    /// Swaps the value at the given index with the last index, so that it can be removed in O(1) time.
    public func swapRemove<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : A {
        if (index >= self.count) {
            Debug.trap("MemoryBuffer swapRemove(): Index out of bounds");
        };

        swap<A>(self, index, self.count - 1);
        remove<A>(self, blobify, self.count - 1);
    };

    /// Reverses the order of the values in the buffer.
    public func reverse<A>(self : MemoryBuffer<A>) {
        for (i in Iter.range(0, (self.count / 2) - 1)) {
            swap<A>(self, i, self.count - i - 1);
        };
    };

    /// Clears the buffer.
    public func clear<A>(self : MemoryBuffer<A>) {
        update_count(self, 0);
        update_start(self, 0);
        update_prev_pages_allocated(self, 0);

        MemoryRegion.clear(self.pointers);
        MemoryRegion.clear(self.blobs);

        init_region_header(self);
    };

    public func clone<A>(self : MemoryBuffer<A>) : MemoryBuffer<A> {
        let new_buffer = MemoryBuffer.new<A>();

        // need to replace with reserve()
        ignore MemoryRegion.allocate(new_buffer.pointers, 12 * self.count);

        for ((i, blob) in Itertools.enumerate(blobs(self))) {
            let mb_address = MemoryRegion.addBlob(new_buffer.blobs, blob);
            let ptr_address = _get_pointer(new_buffer, i);
            MemoryRegion.storeNat64(new_buffer.pointers, ptr_address, Nat64.fromNat(mb_address));
            MemoryRegion.storeNat32(new_buffer.pointers, ptr_address + 8, Nat32.fromNat(blob.size()));
        };

        new_buffer;
    };

    // public func insertBatch<A>(self: MemoryBuffer<A>, blobify: Blobify<A>, index: Nat, batch_size: Nat, values_iter: Iter<A>) {
    //     if (index > self.count) {
    //         Debug.trap("MemoryBuffer: Index out of bounds");
    //     };

    //     if (MemoryRegion.size(self.pointers) < 64 + (POINTER_SIZE * (self.count + batch_size))){
    //         ignore MemoryRegion.allocate(self.pointers, 12 * batch_size); // add space for new pointer
    //     };

    //     shift_pointers(self, index, self.count, batch_size);

    //     var i = index;

    //     label _loop loop switch(values_iter.next()){
    //         case (?val) {
    //             let blob = blobify.to_blob(val);

    //             let mb_address = MemoryRegion.addBlob(self.blobs, blob);
    //             update_pointer_at_index(self, i, mb_address, blob.size());
    //             i += 1;
    //         };
    //         case (null) break _loop;
    //     };

    //     update_count(self, self.count + batch_size);
    // };

    /// Sorts the values in the buffer in ascending order.
    /// This is an implementation of the quicksort algorithm.
    /// The algorithm is unstable and has an average time complexity of O(n log n).
    public func sortUnstable<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, mem_cmp : MemoryCmp.MemoryCmp<A>) {
        if (self.count == 0) return;

        func partition(mbuffer : MemoryBuffer<A>, mem_cmp : MemoryCmp.MemoryCmp<A>, start : Nat, end : Nat) {
            if (start >= end) {
                return;
            };

            // select middle element as pivot
            let mid = (start + end) / 2;
            swap(mbuffer, start, mid);

            var pivot = start;
            var i = start + 1;
            var j = start + 1;

            for (index in Iter.range(pivot + 1, end - 1)) {

                let ord = switch(mem_cmp){
                    case (#blob_cmp(cmp)) {
                        let elem : Blob = _get_blob(mbuffer, get_circular_index(self, index));
                        let pivot_elem : Blob = _get_blob(mbuffer, get_circular_index(self, pivot));
                        cmp(elem, pivot_elem);
                    };
                    case (#cmp(cmp)){
                        let elem : A = get(mbuffer, blobify, index);
                        let pivot_elem : A = get(mbuffer, blobify, pivot);
                        cmp(elem, pivot_elem);
                    };
                };
                
                if (ord == -1) {
                    swap(mbuffer, index, i);
                    i += 1;
                    j += 1;
                } else {
                    swap(mbuffer, index, j);
                    j += 1;
                };
            };

            pivot := Int.abs(i - 1);
            swap(mbuffer, start, pivot);

            partition(mbuffer, mem_cmp, start, pivot);

            partition(mbuffer, mem_cmp, pivot + 1, j);
        };

        partition(self, mem_cmp, 0, self.count);

    };

    /// Randomizes the order of the values in the buffer.
    public func shuffle<A>(self : MemoryBuffer<A>) {
        // shuffle utility functions ported from https://mops.one/fuzz for better performance
        
        if (self.count == 0) return;

        let prime = 456209410580464648418198177201;
		let prime2 = 4451889979529614097557895687536048212109;

        let seed = 0x7eadbeaf;
        var rand = seed;

        var i = 0;
        var end = self.count;

        while (i + 1 < end) {
            let start = i + 1;
            let dist = end - start : Nat;
            
            let j = if (dist == 1) start else {
                rand := (seed * prime + 5) % prime2;

                let max = end - 1;
                let min = start;

                let n_from_range = rand % (max - min + 1) + min;
			    Int.abs(n_from_range);
            };

            swap(self, i, j);

            i += 1;
        };

    };

    public func indexOf<A>(self: MemoryBuffer<A>, blobify: Blobify<A>, equal: (A, A) -> Bool, element: A) : ?Nat {
        for ((i, value) in items(self, blobify)) {
            if (equal(value, element)) {
                return ?i;
            };
        };

        return null;
    };

    public func lastIndexOf<A>(self: MemoryBuffer<A>, blobify: Blobify<A>, equal: (A, A) -> Bool, element: A) : ?Nat {
        for ((i, value) in items(self, blobify).rev()) {
            if (equal(value, element)) {
                return ?i;
            };
        };

        return null;
    };

    public func contains<A>(self: MemoryBuffer<A>, blobify: Blobify<A>, equal: (A, A) -> Bool, element: A) : Bool {
        for (value in vals(self, blobify)) {
            if (equal(value, element)) {
                return true;
            };
        };

        return false;
    };

    public func isEmpty<A>(self: MemoryBuffer<A>) : Bool {
        self.count == 0;
    };

    public func first<A>(self: MemoryBuffer<A>, blobify: Blobify<A>) : A {
        if (self.count == 0) return Debug.trap("MemoryBuffer first(): Buffer is empty");
        get(self, blobify, 0);
    };

    public func last<A>(self: MemoryBuffer<A>, blobify: Blobify<A>) : A {
        if (self.count == 0) return Debug.trap("MemoryBuffer last(): Buffer is empty");
        get(self, blobify, self.count - 1);
    };

    public func peekFirst<A>(self: MemoryBuffer<A>, blobify: Blobify<A>) : ?A {
        getOpt(self, blobify, 0);
    };

    public func peekLast<A>(self: MemoryBuffer<A>, blobify: Blobify<A>) : ?A {
        getOpt(self, blobify, self.count - 1);
    };

    /// Converts a memory buffer to an array.
    public func toArray<A>(self : MemoryBuffer<A>, blobify : Blobify<A>) : [A] {
        Array.tabulate(
            self.count,
            func(i : Nat) : A = get(self, blobify, i),
        );
    };
};
