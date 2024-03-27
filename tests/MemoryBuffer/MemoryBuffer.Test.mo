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
import RevIter "mo:itertools/RevIter";
import MaxBpTreeMethods "mo:augmented-btrees/MaxBpTree/Methods";

import { MemoryBuffer } "../../src";
import Blobify "../../src/Blobify";

import Utils "../../src/Utils";

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
                    MemoryBuffer.add(mbuffer, Blobify.Nat, i);

                    assert MemoryBuffer.get(mbuffer, Blobify.Nat, i) == i;
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
                    assert MemoryBuffer.get(mbuffer, Blobify.Nat, i) == i;

                    MemoryBuffer.put(mbuffer, Blobify.Nat, i, i);
                    validate_region(mbuffer.blobs);
                    validate_region(mbuffer.pointers);
                    assert MemoryBuffer.get(mbuffer, Blobify.Nat, i) == i;
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
                    Debug.print("old " # debug_show (i, pointer, memory_block, blob, Blobify.Nat.to_blob(i)));
                    assert blob == Blobify.Nat.to_blob(i);

                    // Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(mbuffer.blobs.free_memory)));
                    // Debug.print("leaf nodes: " # debug_show (MaxBpTree.toLeafNodes(mbuffer.blobs.free_memory)));
                    MemoryBuffer.put(mbuffer, Blobify.Nat, i, i * 100);

                    validate_region(mbuffer.blobs);
                    validate_region(mbuffer.pointers);

                    let serialized = Blobify.Nat.to_blob(val);

                    let new_pointer = MemoryBuffer._get_pointer(mbuffer, i);
                    let new_memory_block = MemoryBuffer._get_memory_block(mbuffer, i);
                    let new_blob = MemoryBuffer._get_blob(mbuffer, i);

                    Debug.print("new " # debug_show (i, new_pointer, new_memory_block, new_blob));
                    Debug.print("expected " # debug_show serialized);
                    assert new_blob == serialized;
                };

                // Debug.print("put <");
                // for (i in order.vals()) {
                //     MemoryBuffer.put(mbuffer, Blobify.Nat, i, i);
                // };

                // Debug.print("remove");
                // for (i in order.vals()){
                //     ignore MemoryBuffer.remove(mbuffer, Blobify.Nat, Nat.min(i, MemoryBuffer.size(mbuffer) - 1));
                // };

                // Debug.print("insert");
                // for ((iteration_index, i) in Itertools.enumerate(order.vals())) {

                //     Debug.print("memory_info: " # debug_show MemoryRegion.memoryInfo(mbuffer.blobs));
                //     Debug.print("node keys: " # debug_show MaxBpTree.toNodeKeys(mbuffer.blobs.free_memory));
                //     Debug.print("leaf nodes: " # debug_show MaxBpTree.toLeafNodes(mbuffer.blobs.free_memory));
                //     let index = Nat.min(i, MemoryBuffer.size(mbuffer));
                //     let val = i * 100;
                //     MemoryBuffer.insert(mbuffer, Blobify.Nat, index, val);

                //     let ptr_address = MemoryBuffer._get_pointer(mbuffer, index);
                //     let (mb_address, mb_size) = MemoryBuffer._get_memory_block(mbuffer, index);

                //     assert ptr_address == 64 + (index * 12);
                //     // assert MemoryRegion.loadNat64(mbuffer.blobs, ptr_address) == mb_address;
                //     // assert MemoryRegion.loadNat64(mbuffer.blobs, ptr_address + 8) == mb_size;

                //     if (null != MaxBpTree.get(mbuffer.blobs.free_memory, Cmp.Nat, mb_address)) {
                //         Debug.print("error at iteration " # debug_show iteration_index);
                //         Debug.print("same address: " # debug_show (mb_address, mb_size));
                //         Debug.print("free_memory: " # debug_show MaxBpTree.toArray(mbuffer.blobs.free_memory));
                //         Debug.print("node keys: " # debug_show MaxBpTree.toNodeKeys(mbuffer.blobs.free_memory));
                //                 Debug.print("leaf nodes: " # debug_show MaxBpTree.toLeafNodes(mbuffer.blobs.free_memory));
                //         assert false;
                //     };

                //     switch (MaxBpTree.getFloor(mbuffer.blobs.free_memory, Cmp.Nat, mb_address)){
                //         case (null){};
                //         case (?(address, size)) {
                //             if (not ((address + size) <= mb_address)){
                //                 Debug.print("error at iteration " # debug_show iteration_index);
                //                 Debug.print("floor intersection: " # debug_show ((address, size), (mb_address, mb_size)));
                //                 Debug.print("free_memory: " # debug_show MaxBpTree.toArray(mbuffer.blobs.free_memory));
                //                 Debug.print("node keys: " # debug_show MaxBpTree.toNodeKeys(mbuffer.blobs.free_memory));
                //                 Debug.print("leaf nodes: " # debug_show MaxBpTree.toLeafNodes(mbuffer.blobs.free_memory));
                //                 assert false;
                //             };
                //         };
                //     };

                //     switch (MaxBpTree.getCeiling(mbuffer.blobs.free_memory, Cmp.Nat, mb_address)){
                //         case (null){};
                //         case (?(address, size)) {
                //             if (not (mb_address + mb_size <= address)){
                //                 Debug.print("error at iteration " # debug_show iteration_index);
                //                 Debug.print("ceiling intersection: " # debug_show ((address, size), (mb_address, mb_size)));
                //                 Debug.print("free_memory: " # debug_show MaxBpTree.toArray(mbuffer.blobs.free_memory));
                //                 Debug.print("node keys: " # debug_show MaxBpTree.toNodeKeys(mbuffer.blobs.free_memory));
                //                 Debug.print("leaf nodes: " # debug_show MaxBpTree.toLeafNodes(mbuffer.blobs.free_memory));
                //                 assert false;
                //             };
                //         };
                //     };
                // };

                // Debug.print("check");
                // // for ((mb_address, mb_size) in MemoryBuffer.blocks(mbuffer)){

                // // };

                // Debug.print("reverse");
                // MemoryBuffer.reverse(mbuffer);

                // // MemoryBuffer.sortUnstable(mbuffer, Blobify.Nat, Nat.compare);

                // Debug.print("removeLast");
                // for (i in Iter.range(0, limit - 1)) {
                //     Debug.print("removing index " # debug_show i);
                //     ignore MemoryBuffer.removeLast(mbuffer, Blobify.Nat);
                // };
            },
        );

        test(
            "put() (new < prev) in Buffer",
            func() {

                for (i in order.vals()) {

                    assert MemoryBuffer.get(mbuffer, Blobify.Nat, i) == i * 100; // ensures the previous value did not get overwritten

                    let new_value = i;
                    MemoryBuffer.put(mbuffer, Blobify.Nat, i, new_value);
                    // Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(mbuffer.blobs.free_memory)));
                    // Debug.print("leaf nodes: " # debug_show (MaxBpTree.toLeafNodes(mbuffer.blobs.free_memory)));
                    validate_region(mbuffer.blobs);
                    validate_region(mbuffer.pointers);
                    let received = MemoryBuffer.get(mbuffer, Blobify.Nat, i);
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
                    let removed = MemoryBuffer.removeLast(mbuffer, Blobify.Nat);
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
                    MemoryBuffer.add(mbuffer, Blobify.Nat, i);

                    let expected = i;
                    let received = MemoryBuffer.get(mbuffer, Blobify.Nat, i);

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
                let array = MemoryBuffer.toArray(mbuffer, Blobify.Nat);
                MemoryBuffer.reverse(mbuffer);
                let reversed = Array.reverse(array);
                assert reversed == MemoryBuffer.toArray(mbuffer, Blobify.Nat);
            },
        );

        test(
            "remove() from Buffer",
            func() {
                for (i in order.vals()) {
                    let expected = i;
                    let j = Nat.min(i, MemoryBuffer.size(mbuffer) - 1);
                    let removed = MemoryBuffer.remove(mbuffer, Blobify.Nat, j);
                    validate_region(mbuffer.blobs);
                    validate_region(mbuffer.pointers);
                    // Debug.print("(expected, removed) -> " # debug_show (expected, removed));
                    // assert ?expected == removed;
                };
            },
        );

        test(
            "insert()",
            func() {

                for (i in order.vals()) {
                    let j = Nat.min(i, MemoryBuffer.size(mbuffer));
                    MemoryBuffer.insert(mbuffer, Blobify.Nat, j, i);
                    assert MemoryBuffer.get(mbuffer, Blobify.Nat, j) == i;
                };
            },
        );

        test(
            "tabulate",
            func() {
                let mbuffer = MemoryBuffer.tabulate(Blobify.Nat, 10, func(i : Nat) : Nat = i);
                assert MemoryBuffer.size(mbuffer) == 10;
                assert MemoryBuffer.toArray(mbuffer, Blobify.Nat) == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
            },
        );

        test(
            "reverse",
            func() {
                let mbuffer = MemoryBuffer.fromArray(Blobify.Nat, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
                MemoryBuffer.reverse(mbuffer);

                assert MemoryBuffer.toArray(mbuffer, Blobify.Nat) == [9, 8, 7, 6, 5, 4, 3, 2, 1, 0];
            },
        );

        test(
            "sortUnstable",
            func() {
                let mbuffer = MemoryBuffer.fromArray(Blobify.Nat, [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]);

                MemoryBuffer.sortUnstable(mbuffer, Blobify.Nat, Nat.compare);

                assert MemoryBuffer.toArray(mbuffer, Blobify.Nat) == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
            },
        );
    },
);
