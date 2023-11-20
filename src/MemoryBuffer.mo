/// A memory buffer is a data structure that stores a sequence of values in memory.

import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import Region "mo:base/Region";

import MemoryRegion "mo:memory-region/MemoryRegion";

import Utils "Utils";
import Blobify "Blobify";

module MemoryBuffer {
    type Iter<A> = Iter.Iter<A>;
    type MemoryRegion = MemoryRegion.MemoryRegion;
    type Pointer = MemoryRegion.Pointer;

    /// Internal Structure of the memory buffer.
    public type MemoryBuffer<A> = {
        /// The memory region that stores the pointers to the serialized values.
        pointers : MemoryRegion;

        /// The memory region that stores the serialized values.
        blobs : MemoryRegion;

        // cache = LruCache<Nat, A>;

        /// The number of values in the buffer.
        var count : Nat;
    };

    public type MemoryBufferRegion = {
        pointers : MemoryRegion;
        blobs: MemoryRegion;
    };

    public func new_region() : MemoryBufferRegion {
        {
            pointers = MemoryRegion.new();
            blobs = MemoryRegion.new();
        };
    };

    public class MemoryBufferClass<A> (internal_region: MemoryBufferRegion, blobify: Blobify<A>, handle_low_memory: () -> ()){

    };

    /// The Blobify typeclass is used to serialize and deserialize values.
    public type Blobify<A> = Blobify.Blobify<A>;

    /// Creates a new memory buffer.
    public func new<A>() : MemoryBuffer<A> {
        // let cache_size = switch (opt_cache_size) {
        //     case (?size) size;
        //     case (_) 0;
        // };

        return {
            pointers = MemoryRegion.new();
            blobs = MemoryRegion.new();
            // cache = LruCache.new<Nat, A>(cache_size);
            var count = 0;
        };
    };

    /// Initializes a memory buffer with a given value and size.
    public func init<A>(blobify : Blobify<A>, size : Nat, val : A) : MemoryBuffer<A> {
        let sm_buffer = MemoryBuffer.new<A>();

        for (i in Iter.range(1, size)) {
            MemoryBuffer.add(sm_buffer, blobify, val);
        };

        sm_buffer;
    };

    /// Initializes a memory buffer with a given function and size.
    public func tabulate<A>(blobify : Blobify<A>, size : Nat, fn : (i : Nat) -> A) : MemoryBuffer<A> {
        let sm_buffer = MemoryBuffer.new<A>();

        for (i in Iter.range(0, size - 1)) {
            MemoryBuffer.add(sm_buffer, blobify, fn(i));
        };

        sm_buffer;
    };

    /// Initializes a memory buffer with a given array.
    public func fromArray<A>(blobify : Blobify<A>, arr : [A]) : MemoryBuffer<A> {
        let sm_buffer = MemoryBuffer.new<A>();

        for (i in Iter.range(0, arr.size() - 1)) {
            add(sm_buffer, blobify, arr[i]);
        };

        sm_buffer;
    };

    /// Returns the number of elements in the buffer.
    public func size<A>(self : MemoryBuffer<A>) : Nat {
        return self.count;
    };

    /// Returns information about the bytes used by the buffer.
    public func size_info() : () {};

    func blob_pointer_at_index<A>(self : MemoryBuffer<A>, index : Nat) : Blob {
        let address = index * 12;
        MemoryRegion.loadBlob(self.pointers, address, 12);
    };

    func address_at_index<A>(self : MemoryBuffer<A>, index : Nat): Nat {
        let pointer_address = Nat64.fromNat(index * 12);
        let address = Region.loadNat64(self.pointers.region, pointer_address);
        Nat64.toNat(address)
    };

    func size_at_index<A>(self: MemoryBuffer<A>, index: Nat): Nat {
        let pointer_address = Nat64.fromNat(index * 12);
        let value_size = Region.loadNat32(self.pointers.region, pointer_address + 8);

        Nat32.toNat(value_size)
    };

    func update_pointer_at_index<A>(self: MemoryBuffer<A>, index : Nat, address : Nat, size: Nat) {
        let pointer_address = Nat64.fromNat(index * 12);

        let value_address = Nat64.fromNat(address);
        let value_size = Nat32.fromNat(size);

        Region.storeNat64(self.pointers.region, pointer_address, value_address);
        Region.storeNat32(self.pointers.region, pointer_address + 8, value_size);
    };

    func internal_replace<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat, value : A) {
        // let blob_value = switch (LruCache.remove(self.cache, nhash, index)) {
        //     case (?(ptr, _)) { ptr };
        //     case (_) { pointer_at_index(self, index) };
        // };

        let address = address_at_index(self, index);
        let size = size_at_index(self, index);

        // ignore LruCache.remove(self.cache, nhash, address);

        let blob_value = blobify.to_blob(value);

        assert blob_value.size() > 0;

        if (blob_value.size() < size) {
            let extra_address = address + blob_value.size();
            let extra_size = size - blob_value.size() : Nat;

            ignore MemoryRegion.deallocate(self.blobs, extra_address, extra_size);

            MemoryRegion.storeBlob(self.blobs, address, blob_value);
            Region.storeNat32(self.pointers.region, Nat64.fromNat(address + 8), Nat32.fromNat(blob_value.size()));

        }else if (blob_value.size() == size) {
            MemoryRegion.storeBlob(self.blobs, address, blob_value);
            return;
        } else {
            ignore MemoryRegion.deallocate(self.blobs, address, size);
            
            let new_address = MemoryRegion.addBlob(self.blobs, blob_value);

            update_pointer_at_index(self, index, new_address, blob_value.size());
        };

    };

    /// Replaces the value at the given index with the given value.
    public func put<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat, value : A) {
        if (index >= self.count) {
            Debug.trap("MemoryBuffer: Index out of bounds");
        };

        internal_replace(self, blobify, index, value);
    };

    /// Retrieves the value at the given index if it exists. Otherwise returns null.
    public func getOpt<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : ?A {
        if (index >= self.count) {
            return null;
        };

        let value = get(self, blobify, index);

        return ?value;
    };

    func get_without_cache_update<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : A {
        let address = address_at_index(self, index);

        // switch (LruCache.get(self.cache, nhash, address)) {
        //     case (?value) return value;
        //     case (_) {};
        // };

        let size = size_at_index(self, index);

        let blob_value = MemoryRegion.loadBlob(self.blobs, address, size);
        blobify.from_blob(blob_value);
    };

    /// Retrieves the value at the given index. Traps if the index is out of bounds.
    public func get<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : A {
        let val =  get_without_cache_update(self, blobify, index);

        // LruCache.put(self.cache, nhash, address, value);

        val
    };

    /// Adds a value to the end of the buffer.
    public func add<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, value : A) {
        let blob_value = blobify.to_blob(value);
        assert blob_value.size() > 0; // handle in memory_region (just ignore empty sizes)
        let address = MemoryRegion.addBlob(self.blobs, blob_value);

        MemoryRegion.growIfNeeded(self.pointers, 12);
        update_pointer_at_index(self, self.count, address, blob_value.size());
        self.pointers.size += 12;

        self.count += 1;
    };

    /// Adds all the values from the given buffer to the end of this buffer.
    public func append<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, other : MemoryBuffer<A>) {
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

    /// Returns an iterator over the values in the buffer.
    public func vals<A>(self : MemoryBuffer<A>, blobify : Blobify<A>) : Iter<A> {
        var i = 0;

        return object {
            public func next() : ?A {
                if (i >= self.count) {
                    return null;
                };
                
                let val = get_without_cache_update(self, blobify, i);
                i += 1;
                ?val;
            };
        };
    };

    func shift_pointers<A>(self : MemoryBuffer<A>, start : Nat, end : Nat, n : Int) {
        let start_address = start * 12;
        let size = (end - start : Nat) * 12;
        if (size == 0) return ();

        let pointers_blob = MemoryRegion.loadBlob(self.pointers, start_address, size);

        let new_index = Int.abs(start + n);

        let new_address = new_index * 12;

        MemoryRegion.storeBlob(self.pointers, new_address, pointers_blob);

    };

    /// Removes the value at the given index. Traps if the index is out of bounds.
    public func remove<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : A {
        if (index >= self.count) {
            Debug.trap("MemoryBuffer: Index out of bounds");
        };

        let address = address_at_index(self, index);
        let size = size_at_index(self, index);

        let blob_value = MemoryRegion.removeBlob(self.blobs, address, size);
        let value = blobify.from_blob(blob_value);
        // let value = switch(LRUCache.remove(self.cache, nhash, address)) {
        //     case (?value) { 
        //          ignore MemoryRegion.deallocate(self.blobs, address, size);
        //          value 
        //     };
        //     case (_) { 
        //          let blob_value = MemoryRegion.removeBlob(self.blobs, address, size);
        //          blobify.from_blob(blob_value) 
        //     };
        // };


        shift_pointers(self, index + 1, self.count, -1);
        self.count -= 1;

        return value;
    };

    /// Removes the last value in the buffer, if it exists. Otherwise returns null.
    public func removeLast<A>(self : MemoryBuffer<A>, blobify : Blobify<A>) : ?A {
        if (self.count == 0) {
            return null;
        };

        ?remove(self, blobify, (self.count - 1) : Nat);
    };

    /// Swaps the values at the given indices.
    public func swap<A>(self : MemoryBuffer<A>, index_a : Nat, index_b : Nat) {
        let blob_ptr_a = blob_pointer_at_index(self, index_a);
        let blob_ptr_b = blob_pointer_at_index(self, index_b);

        MemoryRegion.storeBlob(self.pointers, index_a * 12, blob_ptr_b);
        MemoryRegion.storeBlob(self.pointers, index_b * 12, blob_ptr_a);
    };

    /// Swaps the value at the given index with the last index, so that it can be removed in O(1) time.
    public func swapRemove<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat) {
        swap<A>(self, index, self.count - 1);
        ignore remove<A>(self, blobify, self.count - 1);
    };

    /// Reverses the order of the values in the buffer.
    public func reverse<A>(self: MemoryBuffer<A>) {
        for (i in Iter.range(0, (self.count / 2) - 1)) {
            swap<A>(self, i, self.count - i - 1);
        };
    };

    /// Clears the buffer.
    public func clear<A>(self : MemoryBuffer<A>) {
        self.count := 0;
        MemoryRegion.clear(self.pointers);
        MemoryRegion.clear(self.blobs);
        // LruCache.clear(self.cache);
    };

    /// Inserts a value at the given index.
    public func insert<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat, value : A) {
        if (index == self.count) {
            add(self, blobify, value);
            return;
        };

        if (index > self.count) {
            Debug.trap("MemoryBuffer: Index out of bounds");
        };

        ignore MemoryRegion.allocate(self.pointers, 12); // add space for new pointer
        
        shift_pointers(self, index, self.count, 1);

        let value_blob = blobify.to_blob(value);
        assert value_blob.size() > 0;

        let address = MemoryRegion.addBlob(self.blobs, value_blob);

        update_pointer_at_index(self, index, address, value_blob.size());

        self.count += 1;
    };

    /// Converts a memory buffer to an array.
    public func toArray<A>(self : MemoryBuffer<A>, blobify : Blobify<A>) : [A] {
        Array.tabulate(
            self.count,
            func(i : Nat) : A = get(self, blobify, i),
        );
    };
};
