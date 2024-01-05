// @testmode wasi
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Prelude "mo:base/Prelude";

import { test; suite } "mo:test";
import Fuzz "mo:fuzz";
import MaxBpTree "mo:augmented-btrees/MaxBpTree";
import MemoryRegion "mo:memory-region/MemoryRegion";

import { MemoryBuffer } "../src";
import Blobify "../src/Blobify";

import Utils "../src/Utils";

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

suite(
    "Memory Buffer",
    func() {
        let buffer = MemoryBuffer.new<Nat>();

        test(
            "add() to Buffer",
            func() {
                for (i in Iter.range(0, limit - 1)) {
                    MemoryBuffer.add(buffer, candid_blobify, i);

                    assert MemoryBuffer.size(buffer) == i + 1;
                    assert MemoryBuffer.get(buffer, candid_blobify, i) == i;
                };
            },
        );
        test(
            "get() from Buffer",
            func() {

                // for (i in Iter.range(0, limit - 1)) {
                //     assert MemoryBuffer.get(buffer, candid_blobify, i) == i;
                // };

                let buffer = MemoryBuffer.fromArray(candid_blobify, [1, 2, 3, 4, 5]);

                assert MemoryBuffer.get(buffer, candid_blobify, 0) == 1;
                assert MemoryBuffer.get(buffer, candid_blobify, 2) == 3;
                assert MemoryBuffer.get(buffer, candid_blobify, 4) == 5;

                assert MemoryBuffer.toArray(buffer, candid_blobify) == [1, 2, 3, 4, 5];

            },
        );

        // test(
        //     "remove() from Buffer",
        //     func() {
        //         let buffer = MemoryBuffer.new<Nat>();

        //         MemoryBuffer.appendArray(buffer, candid_blobify, [1, 2, 3, 4, 5]);

        //         assert 2 == MemoryBuffer.remove(buffer, candid_blobify, 1);
        //         assert 3 == MemoryBuffer.remove(buffer, candid_blobify, 1);
        //         assert 4 == MemoryBuffer.remove(buffer, candid_blobify, 1);

        //         assert MemoryBuffer.toArray(buffer, candid_blobify) == [1, 5];
        //     },
        // );

        // test(
        //     "removeLast() from Buffer",
        //     func() {
        //         let buffer = MemoryBuffer.new<Nat>();

        //         MemoryBuffer.appendArray(buffer, candid_blobify, [1, 2, 3, 4, 5]);

        //         assert ?5 == MemoryBuffer.removeLast(buffer, candid_blobify);
        //         assert ?4 == MemoryBuffer.removeLast(buffer, candid_blobify);
        //         assert ?3 == MemoryBuffer.removeLast(buffer, candid_blobify);

        //         assert MemoryBuffer.toArray(buffer, candid_blobify) == [1, 2];
        //     },
        // );

        test(
            "put() (new == prev) in Buffer",
            func() {
                for (i in order.vals()) {
                    assert MemoryBuffer.get(buffer, candid_blobify, i) == i;

                    MemoryBuffer.put(buffer, candid_blobify, i, i);
                    assert MemoryBuffer.get(buffer, candid_blobify, i) == i;
                };
            },
        );

        test(
            "put() (new > prev) in Buffer",
            func() {
                var seen = false;

                for (i in order.vals()) {
                    assert MemoryBuffer.get(buffer, candid_blobify, i) == i;

                    if (i == 7_305){
                        Debug.print("max value at (i == 7305): " # debug_show (MaxBpTree.maxValue(buffer.blobs.free_memory)));
                        Debug.print("contains (44_508, 10): ()" # debug_show MemoryRegion.isFreed(buffer.blobs, 44_508, 10));
                    };

                    let new_value = i * 10;
                    MemoryBuffer.put(buffer, candid_blobify, i, new_value);

                    let received = MemoryBuffer.get(buffer, candid_blobify, i);
                    if (received != new_value) {
                        Debug.print("mismatch at i = " # debug_show i);
                        Debug.print("(exprected, received) -> " # debug_show (new_value, received));

                        assert false;
                    };

                    if (i == 1_858)  {
                        seen := true;
                        Debug.print(debug_show MaxBpTree.toArray(buffer.blobs.free_memory));
                    };

                    if (seen){
                        Debug.print("contains (44_508, 10): ()" # debug_show MemoryRegion.isFreed(buffer.blobs, 44_508, 10));
                    };

                    if (seen and MemoryBuffer.get(buffer, candid_blobify, 1_858) != 1_8580) {
                        Debug.print("contains (44_508, 10): ()" # debug_show MemoryRegion.isFreed(buffer.blobs, 44_508, 10));
                    };

                    // ignore MemoryBuffer.get(buffer, candid_blobify, 67);
                };

            },
        );

        test(
            "put() (new < prev) in Buffer",
            func() {

                for (i in order.vals()) {

                    assert MemoryBuffer.get(buffer, candid_blobify, i) == i * 10; // ensures the previous value did not get overwritten

                    let new_value = i / 10;
                    MemoryBuffer.put(buffer, candid_blobify, i, new_value);

                    let received = MemoryBuffer.get(buffer, candid_blobify, i);
                    if (received != new_value) {
                        Debug.print("mismatch at i = " # debug_show i);
                        Debug.print("(exprected, received) -> " # debug_show (new_value, received));

                        assert false;
                    };

                    // ignore MemoryBuffer.get(buffer, candid_blobify, 67);

                };
            },
        );

        // test(
        //     "insert()",
        //     func() {
        //         let buffer = MemoryBuffer.fromArray(candid_blobify, [0, 10, 20]);

        //         assert MemoryBuffer.toArray(buffer, candid_blobify) == [0, 10, 20];
        //         assert MemoryBuffer.size(buffer) == 3;

        //         for (i in Iter.range(1, 9)) {
        //             MemoryBuffer.insert(buffer, candid_blobify, i, i);
        //         };

        //         assert MemoryBuffer.size(buffer) == 12;

        //         for (i in Iter.range(11, 19)) {
        //             MemoryBuffer.insert(buffer, candid_blobify, i, i);
        //         };

        //         assert MemoryBuffer.size(buffer) == 21;
        //         assert MemoryBuffer.toArray(buffer, candid_blobify) == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20];

        //     },
        // );

        // test(
        //     "tabulate",
        //     func() {
        //         let buffer = MemoryBuffer.tabulate(candid_blobify, 10, func(i : Nat) : Nat = i);
        //         assert MemoryBuffer.size(buffer) == 10;
        //         assert MemoryBuffer.toArray(buffer, candid_blobify) == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
        //     },
        // );

        // test(
        //     "reverse",
        //     func() {
        //         let buffer = MemoryBuffer.fromArray(candid_blobify, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
        //         MemoryBuffer.reverse(buffer);

        //         assert MemoryBuffer.toArray(buffer, candid_blobify) == [9, 8, 7, 6, 5, 4, 3, 2, 1, 0];
        //     },
        // )

    },
);
