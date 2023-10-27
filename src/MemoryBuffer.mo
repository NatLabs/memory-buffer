import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import Region "mo:base/Region";

import MemoryRegion "mo:memory-region/MemoryRegion";
import StableBuffeer "mo:StableBuffer/StableBuffer";
import Itertools "mo:itertools/Iter";
import Map "mo:map/Map";

import Utils "Utils";
import Blobify "Blobify";

module MemoryBuffer {
    type Iter<A> = Iter.Iter<A>;
    type MemoryRegion = MemoryRegion.MemoryRegion;
    type Pointer = MemoryRegion.Pointer;
    // type LruCache<A, B> = LruCache.LruCache<A, B>;
    type Map<A, B> = Map.Map<A, B>;

    type WriteAheadLog = Map<Text, Map<Nat, Blob>>;

    public type MemoryBuffer<A> = {
        pointers : MemoryRegion;
        blobs : MemoryRegion;
        // log: WriteAheadLog;
        // cache : LruCache<Nat, (Pointer, A)>;
        var count : Nat;
    };

    // let { nhash } = LruCache;

    public type Blobify<A> = Blobify.Blobify<A>;

    public func new<A>(opt_cache_size : ?Nat) : MemoryBuffer<A> {
        let cache_size = switch (opt_cache_size) {
            case (?size) size;
            case (_) 0;
        };

        let buffer = {
            pointers = MemoryRegion.new();
            blobs = MemoryRegion.new();
            // cache = LruCache.new<Nat, (Pointer, A)>(cache_size);
            var count = 0;
        };

        ignore Region.grow(buffer.pointers.region, 5);
        ignore Region.grow(buffer.blobs.region, 5);

        buffer;
    };

    public func init<A>(blobify : Blobify<A>, size : Nat, val : A) : MemoryBuffer<A> {
        let sm_buffer = MemoryBuffer.new<A>(null);

        for (i in Iter.range(1, size)) {
            MemoryBuffer.add(sm_buffer, blobify, val);
        };

        sm_buffer;
    };

    public func tabulate<A>(blobify : Blobify<A>, size : Nat, fn : (i : Nat) -> A) : MemoryBuffer<A> {
        let sm_buffer = MemoryBuffer.new<A>(null);

        for (i in Iter.range(0, size - 1)) {
            MemoryBuffer.add(sm_buffer, blobify, fn(i));
        };

        sm_buffer;
    };

    public func fromArray<A>(blobify : Blobify<A>, arr : [A]) : MemoryBuffer<A> {
        let sm_buffer = MemoryBuffer.new<A>(null);

        for (i in Iter.range(0, arr.size() - 1)) {
            MemoryBuffer.add(sm_buffer, blobify, arr[i]);
        };

        sm_buffer;
    };

    public func size<A>(self : MemoryBuffer<A>) : Nat {
        return self.count;
    };

    public func size_info() : () {};

    func encode_pointer(address: Nat, size: Nat) : Blob {
        let address_64 = Nat64.fromNat(address);
        let size_64 = Nat64.fromNat(size);

        // performs 50% better than Array.tabulate()
        let arr : [Nat8] = [
            Nat8.fromNat(Nat64.toNat((address_64 >> 56) & 0xff)),
            Nat8.fromNat(Nat64.toNat((address_64 >> 48) & 0xff)),
            Nat8.fromNat(Nat64.toNat((address_64 >> 40) & 0xff)),
            Nat8.fromNat(Nat64.toNat((address_64 >> 32) & 0xff)),
            Nat8.fromNat(Nat64.toNat((address_64 >> 24) & 0xff)),
            Nat8.fromNat(Nat64.toNat((address_64 >> 16) & 0xff)),
            Nat8.fromNat(Nat64.toNat((address_64 >> 8) & 0xff)),
            Nat8.fromNat(Nat64.toNat(address_64 & 0xff)),
            Nat8.fromNat(Nat64.toNat((size_64 >> 24) & 0xff)),
            Nat8.fromNat(Nat64.toNat((size_64 >> 16) & 0xff)),
            Nat8.fromNat(Nat64.toNat((size_64 >> 8) & 0xff)),
            Nat8.fromNat(Nat64.toNat(size_64 & 0xff)),
        ];

        return Blob.fromArray(arr);
    };

    func decode_pointer(blob : Blob) : Pointer {
        let bytes = Blob.toArray(blob);

        let address = address_from_pointer_bytes(bytes);
        let size = size_from_pointer_bytes(bytes);

        return (address, size);
    };
    
    func pointer_at_index<A>(self : MemoryBuffer<A>, index : Nat) : Pointer {
        let address = index * 12;
        let pointer_blob = MemoryRegion.loadBlob(self.pointers, address, 12);
        decode_pointer(pointer_blob);
    };

     func address_from_pointer_bytes<A>(bytes: [Nat8]): Nat {
        var address_64 : Nat64 = Nat64.fromNat(Nat8.toNat(bytes[0])) << 56
            | Nat64.fromNat(Nat8.toNat(bytes[1])) << 48 
            | Nat64.fromNat(Nat8.toNat(bytes[2])) << 40
            | Nat64.fromNat(Nat8.toNat(bytes[3])) << 32
            | Nat64.fromNat(Nat8.toNat(bytes[4])) << 24
            | Nat64.fromNat(Nat8.toNat(bytes[5])) << 16
            | Nat64.fromNat(Nat8.toNat(bytes[6])) << 8
            | Nat64.fromNat(Nat8.toNat(bytes[7]));

        Nat64.toNat(address_64);
    };

    func size_from_pointer_bytes<A>(bytes: [Nat8]): Nat {
        var size_64 : Nat64 = Nat64.fromNat(Nat8.toNat(bytes[8])) << 24
            | Nat64.fromNat(Nat8.toNat(bytes[9])) << 16
            | Nat64.fromNat(Nat8.toNat(bytes[10])) << 8
            | Nat64.fromNat(Nat8.toNat(bytes[11]));

        Nat64.toNat(size_64)
    };

    func update_pointer_at_index<A>(self: MemoryBuffer<A>, index : Nat, pointer : Pointer) {
        let address = index * 12;
        let pointer_blob = encode_pointer(pointer);
        MemoryRegion.storeBlob(self.pointers, address, pointer_blob);
    };

    func internal_replace<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat, value : A) {
        // var pointer = switch (LruCache.remove(self.cache, nhash, index)) {
        //     case (?(ptr, _)) { ptr };
        //     case (_) { pointer_at_index(self, index) };
        // };

        var pointer = pointer_at_index(self, index);

        let blob_value = blobify.to_blob(value);
        assert blob_value.size() > 0;

        if (blob_value.size() == pointer.1){
            MemoryRegion.storeBlob(self.blobs, pointer.0, blob_value);
            return;
        } else {
            ignore MemoryRegion.deallocate(self.blobs, pointer.0, pointer.1);
            
            let address = MemoryRegion.addBlob(self.blobs, blob_value);
            pointer := (address, blob_value.size());

            update_pointer_at_index(self, index, pointer);
        };

        // LruCache.put(self.cache, nhash, index, (pointer, value));
    };

    public func put<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat, value : A) : () {
        if (index >= self.count) {
            Debug.trap("MemoryBuffer: Index out of bounds");
        };

        internal_replace(self, blobify, index, value);
    };

    public func getOpt<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : ?A {
        if (index >= self.count) {
            return null;
        };

        let value = get(self, blobify, index);

        return ?value;
    };

    public func get<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : A {
        let (address, size) = pointer_at_index(self, index);
        let blob_value = MemoryRegion.loadBlob(self.blobs, address, size);
        return blobify.from_blob(blob_value);
    };

    public func add<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, value : A) {
        let blob_value = blobify.to_blob(value);
        assert blob_value.size() > 0;
        let address = MemoryRegion.addBlob(self.blobs, blob_value);

        let pointer_blob = encode_pointer(address, blob_value.size());
        ignore MemoryRegion.addBlob(self.pointers, pointer_blob);

        // LruCache.put(self.cache, nhash, self.count, (pointer, value));
        self.count += 1;
    };

    public func append<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, other : MemoryBuffer<A>) {
        for (value in vals(other, blobify)) {
            add(self, blobify, value);
        };
    };

    public func appendArray<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, blobs : [A]) {
        for (value in blobs.vals()) {
            add(self, blobify, value);
        };
    };

    public func appendBuffer<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, other : { vals : () -> Iter<A> }) {
        for (value in other.vals()) {
            add(self, blobify, value);
        };
    };

    public func vals<A>(self : MemoryBuffer<A>, blobify : Blobify<A>) : Iter<A> {
        var i = 0;

        return object {
            public func next() : ?A {
                let val = getOpt(self, blobify, i);
                i += 1;
                val;
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

    public func remove<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : A {
        if (index >= self.count) {
            Debug.trap("MemoryBuffer: Index out of bounds");
        };

        let ptr = pointer_at_index(self, index);
        let (address, size) = ptr;

        let blob_value = MemoryRegion.removeBlob(self.blobs, address, size);
        let value = blobify.from_blob(blob_value);

        shift_pointers(self, index + 1, self.count, -1);
        self.count -= 1;

        return value;
    };

    public func removeLast<A>(self : MemoryBuffer<A>, blobify : Blobify<A>) : ?A {
        if (self.count == 0) {
            return null;
        };

        let ptr = 

        ?remove(self, blobify, (self.count - 1) : Nat);
    };

    public func swap<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index_a : Nat, index_b : Nat) {
        let ptr_a = pointer_at_index(self, index_a);
        let ptr_b = pointer_at_index(self, index_b);

        MemoryRegion.storeBlob(self.pointers, index_a * 12, encode_pointer(ptr_b));
        MemoryRegion.storeBlob(self.pointers, index_b * 12, encode_pointer(ptr_a));
    };

    public func swap_remove<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat) {
        swap<A>(self, blobify, index, self.count - 1);
        ignore remove<A>(self, blobify, self.count - 1);
    };

    public func clear<A>(self : MemoryBuffer<A>) {
        self.count := 0;
        // LruCache.clear(self.cache);
    };

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

        let pointer = (address, value_blob.size());
        update_pointer_at_index(self, index, pointer);

        self.count += 1;
    };

    public func toArray<A>(self : MemoryBuffer<A>, blobify : Blobify<A>) : [A] {
        Array.tabulate(
            self.count,
            func(i : Nat) : A = get(self, blobify, i),
        );
    };
};
