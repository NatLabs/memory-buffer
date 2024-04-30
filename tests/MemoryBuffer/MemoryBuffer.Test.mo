// @testmode wasi
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Prelude "mo:base/Prelude";
import Nat "mo:base/Nat";
import Array "mo:base/Array";

import { test; suite } "mo:test";
import Fuzz "mo:fuzz";
import { MaxBpTree; Cmp } "mo:augmented-btrees";
import MemoryRegion "mo:memory-region/MemoryRegion";
import Itertools "mo:itertools/Iter";
import MaxBpTreeMethods "mo:augmented-btrees/MaxBpTree/Methods";

import MemoryBuffer "../../src/MemoryBuffer/Base";
import Blobify "../../src/Blobify";

import Utils "../../src/Utils";
import MemoryCmp "../../src/MemoryCmp";
import Int8Cmp "../../src/Int8Cmp";

let candid_blobify : Blobify.Blobify<Nat> = {
    from_blob = func(b : Blob) : Nat {
        let ?n : ?Nat = from_candid (b) else {
            Debug.trap("Failed to decode Nat from blob");
        };
        n;
    };
    to_blob = func(n : Nat) : Blob = to_candid (n);
};

let limit = 10_000;
let order = Buffer.Buffer<Nat>(limit);
let values = Buffer.Buffer<Nat>(limit);

for (i in Iter.range(0, limit - 1)) {
    order.add(i);
};

let fuzz = Fuzz.fromSeed(0x7f7f);
Utils.shuffle_buffer(fuzz, order);

type MemoryRegion = MemoryRegion.MemoryRegion;

func validate_region(memory_region : MemoryRegion) {
    if (not MaxBpTreeMethods.validate_max_path(memory_region.free_memory, Cmp.Nat)) {
        Debug.print("invalid max path discovered at index ");
        Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(memory_region.free_memory)));
        Debug.print("node leaves: " # debug_show (MaxBpTree.toLeafNodes(memory_region.free_memory)));
        assert false;
    };

    if (not MaxBpTreeMethods.validate_subtree_size(memory_region.free_memory)) {
        Debug.print("invalid subtree size at index ");
        Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(memory_region.free_memory)));
        Debug.print("node leaves: " # debug_show (MaxBpTree.toLeafNodes(memory_region.free_memory)));
        assert false;
    };
};

suite(
    "Memory Buffer",
    func() {
        let mbuffer = MemoryBuffer.new<Nat>();

        test(
            "add() to Buffer",
            func() {
                for (i in Iter.range(0, limit - 1)) {
                    MemoryBuffer.add(mbuffer, Blobify.BigEndian.Nat, i);
                    values.add(i);

                    assert MemoryBuffer.get(mbuffer, Blobify.BigEndian.Nat, i) == i;
                    assert MemoryBuffer.size(mbuffer) == i + 1;

                    assert MemoryRegion.size(mbuffer.pointers) == 64 + (MemoryBuffer.size(mbuffer) * 12);
                };

                assert ?(MemoryRegion.size(mbuffer.blobs) - 64) == Itertools.sum(
                    Iter.map(
                        MemoryBuffer.blocks(mbuffer),
                        func((address, size) : (Nat, Nat)) : Nat = size,
                    ),
                    Nat.add,
                );
            },
        );
        test(
            "put() (new == prev) in Buffer",
            func() {
                for (i in order.vals()) {
                    assert MemoryBuffer.get(mbuffer, Blobify.BigEndian.Nat, i) == i;

                    MemoryBuffer.put(mbuffer, Blobify.BigEndian.Nat, i, i);
                    validate_region(mbuffer.blobs);
                    validate_region(mbuffer.pointers);
                    assert MemoryBuffer.get(mbuffer, Blobify.BigEndian.Nat, i) == i;
                };
            },
        );

        test(
            "put() new > old",
            func() {
                for (i in order.vals()) {
                    let val = i * 100;
                    let pointer = MemoryBuffer._get_pointer(mbuffer, i);
                    let memory_block = MemoryBuffer._get_memory_block(mbuffer, i);
                    let blob = MemoryBuffer._get_blob(mbuffer, i);
                    // Debug.print("old " # debug_show (i, pointer, memory_block, blob, Blobify.BigEndian.Nat.to_blob(i)));
                    assert blob == Blobify.BigEndian.Nat.to_blob(i);

                    // Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(mbuffer.blobs.free_memory)));
                    // Debug.print("leaf nodes: " # debug_show (MaxBpTree.toLeafNodes(mbuffer.blobs.free_memory)));
                    MemoryBuffer.put(mbuffer, Blobify.BigEndian.Nat, i, i * 100);

                    validate_region(mbuffer.blobs);
                    validate_region(mbuffer.pointers);

                    let serialized = Blobify.BigEndian.Nat.to_blob(val);

                    let new_pointer = MemoryBuffer._get_pointer(mbuffer, i);
                    let new_memory_block = MemoryBuffer._get_memory_block(mbuffer, i);
                    let new_blob = MemoryBuffer._get_blob(mbuffer, i);

                    // Debug.print("new " # debug_show (i, new_pointer, new_memory_block, new_blob));
                    // Debug.print("expected " # debug_show serialized);
                    assert new_blob == serialized;
                };

            },
        );

        test(
            "put() (new < prev) in Buffer",
            func() {

                for (i in order.vals()) {

                    assert MemoryBuffer.get(mbuffer, Blobify.BigEndian.Nat, i) == i * 100; // ensures the previous value did not get overwritten

                    let new_value = i;
                    MemoryBuffer.put(mbuffer, Blobify.BigEndian.Nat, i, new_value);
                    // Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(mbuffer.blobs.free_memory)));
                    // Debug.print("leaf nodes: " # debug_show (MaxBpTree.toLeafNodes(mbuffer.blobs.free_memory)));
                    validate_region(mbuffer.blobs);
                    validate_region(mbuffer.pointers);
                    let received = MemoryBuffer.get(mbuffer, Blobify.BigEndian.Nat, i);
                    if (received != new_value) {
                        Debug.print("mismatch at i = " # debug_show i);
                        Debug.print("(exprected, received) -> " # debug_show (new_value, received));

                        assert false;
                    };
                };
            },
        );

        test(
            "removeLast() from Buffer",
            func() {

                for (i in Iter.range(0, limit - 1)) {
                    let expected = limit - i - 1;
                    
                    let removed = MemoryBuffer.removeLast(mbuffer, Blobify.BigEndian.Nat);

                    validate_region(mbuffer.blobs);
                    validate_region(mbuffer.pointers);
                    // Debug.print("(expected, removed) -> " # debug_show (expected, removed));
                    assert ?expected == removed;
                };
            },
        );

        test(
            "add() reallocation",
            func() {
                assert MemoryBuffer.size(mbuffer) == 0;

                for (i in Iter.range(0, limit - 1)) {
                    MemoryBuffer.add(mbuffer, Blobify.BigEndian.Nat, i);

                    let expected = i;
                    let received = MemoryBuffer.get(mbuffer, Blobify.BigEndian.Nat, i);

                    if (expected != received) {
                        Debug.print("mismatch at i = " # debug_show i);
                        Debug.print("(exprected, received) -> " # debug_show (expected, received));
                        assert false;
                    };

                    assert MemoryBuffer.size(mbuffer) == i + 1;
                };

            },
        );

        test(
            "reverse()",
            func() {
                let array = MemoryBuffer.toArray(mbuffer, Blobify.BigEndian.Nat);
                MemoryBuffer.reverse(mbuffer);
                let reversed = Array.reverse(array);
                assert reversed == MemoryBuffer.toArray(mbuffer, Blobify.BigEndian.Nat);
            },
        );

        test(
            "remove() from Buffer",
            func() {
                var size = order.size();

                for (i in order.vals()) {
                    assert MemoryBuffer.size(mbuffer) == size;

                    let expected = i;
                    let j = Nat.min(i, MemoryBuffer.size(mbuffer) - 1);
                    let removed = MemoryBuffer.remove(mbuffer, Blobify.BigEndian.Nat, j);
                    validate_region(mbuffer.blobs);
                    validate_region(mbuffer.pointers);

                    size -= 1;
                };

                assert MemoryBuffer.size(mbuffer) == size;

            },
        );

        test(
            "insert()",
            func() {

                for (i in order.vals()) {
                    let j = Nat.min(i, MemoryBuffer.size(mbuffer));
                    MemoryBuffer.insert(mbuffer, Blobify.BigEndian.Nat, j, i);
                    assert MemoryBuffer.get(mbuffer, Blobify.BigEndian.Nat, j) == i;
                };
            },
        );

        test(
            "tabulate",
            func() {
                let mbuffer = MemoryBuffer.tabulate(Blobify.BigEndian.Nat, limit, func(i : Nat) : Nat = i);
                assert MemoryBuffer.size(mbuffer) == limit;
                for (i in Iter.range(0, limit - 1)) {
                    let n = MemoryBuffer.get(mbuffer, Blobify.BigEndian.Nat, i);
                    assert n == i;
                };
            },
        );

        test ("shuffle", func() {
            MemoryBuffer.shuffle(mbuffer);

            for (i in Iter.range(0, limit - 1)) {
                let n = MemoryBuffer.get(mbuffer, Blobify.BigEndian.Nat, i);
            };
        });

        test(
            "sortUnstable",
            func() {
                MemoryBuffer.sortUnstable<Nat>(mbuffer, Blobify.BigEndian.Nat, MemoryCmp.BigEndian.Nat);

                var prev = MemoryBuffer.get(mbuffer, Blobify.BigEndian.Nat, 0);
                for (i in Iter.range(1, limit - 1)) {
                    let n = MemoryBuffer.get(mbuffer, Blobify.BigEndian.Nat, i);
                    assert prev <= n;
                    prev := n;
                };
            },
        );
    },
);
