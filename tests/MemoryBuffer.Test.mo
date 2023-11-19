// @testmode wasi
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Prelude "mo:base/Prelude";
import { test; suite } "mo:test";

import { MemoryBuffer; Blobify } "../src";

suite(
    "Memory Buffer",
    func() {
        test(
            "add() to Buffer",
            func() {
                let buffer = MemoryBuffer.new<Nat>(?10);

                MemoryBuffer.add(buffer, Blobify.Nat, 1);
                MemoryBuffer.add(buffer, Blobify.Nat, 2);
                MemoryBuffer.add(buffer, Blobify.Nat, 3);

                assert MemoryBuffer.toArray(buffer, Blobify.Nat) == [1, 2, 3];
                assert MemoryBuffer.size(buffer) == 3;
            },
        );
        test(
            "get() from Buffer",
            func() {
                let buffer = MemoryBuffer.fromArray(Blobify.Nat, [1, 2, 3, 4, 5]);

                assert MemoryBuffer.get(buffer, Blobify.Nat, 0) == 1;
                assert MemoryBuffer.get(buffer, Blobify.Nat, 2) == 3;
                assert MemoryBuffer.get(buffer, Blobify.Nat, 4) == 5;

                assert MemoryBuffer.toArray(buffer, Blobify.Nat) == [1, 2, 3, 4, 5];

            },
        );

        test(
            "remove() from Buffer",
            func() {
                let buffer = MemoryBuffer.new<Nat>(?10);

                MemoryBuffer.appendArray(buffer, Blobify.Nat, [1, 2, 3, 4, 5]);

                assert 2 == MemoryBuffer.remove(buffer, Blobify.Nat, 1);
                assert 3 == MemoryBuffer.remove(buffer, Blobify.Nat, 1);
                assert 4 == MemoryBuffer.remove(buffer, Blobify.Nat, 1);

                assert MemoryBuffer.toArray(buffer, Blobify.Nat) == [1, 5];
            },
        );

        test(
            "removeLast() from Buffer",
            func() {
                let buffer = MemoryBuffer.new<Nat>(?10);

                MemoryBuffer.appendArray(buffer, Blobify.Nat, [1, 2, 3, 4, 5]);

                assert ?5 == MemoryBuffer.removeLast(buffer, Blobify.Nat);
                assert ?4 == MemoryBuffer.removeLast(buffer, Blobify.Nat);
                assert ?3 == MemoryBuffer.removeLast(buffer, Blobify.Nat);

                assert MemoryBuffer.toArray(buffer, Blobify.Nat) == [1, 2];
            },
        );


        test(
            "put() in Buffer",
            func() {
                let arr : [Nat] = [1, 2, 3, 4, 5];
                let buffer = MemoryBuffer.fromArray<Nat>(Blobify.Nat, arr);

                assert MemoryBuffer.toArray(buffer, Blobify.Nat) == arr;
                assert MemoryBuffer.size(buffer) == 5;

                MemoryBuffer.put(buffer, Blobify.Nat, 1, 10);
                MemoryBuffer.put(buffer, Blobify.Nat, 2, 20);
                MemoryBuffer.put(buffer, Blobify.Nat, 3, 30);

                assert MemoryBuffer.toArray(buffer, Blobify.Nat) == [1, 10, 20, 30, 5];
            },
        );

        test(
            "insert()",
            func() {
                let buffer = MemoryBuffer.fromArray(Blobify.Nat, [0, 10, 20]);

                assert MemoryBuffer.toArray(buffer, Blobify.Nat) == [0, 10, 20];
                assert MemoryBuffer.size(buffer) == 3;

                for (i in Iter.range(1, 9)) {
                    MemoryBuffer.insert(buffer, Blobify.Nat, i, i);
                };

                assert MemoryBuffer.size(buffer) == 12;

                for (i in Iter.range(11, 19)) {
                    MemoryBuffer.insert(buffer, Blobify.Nat, i, i);
                };

                assert MemoryBuffer.size(buffer) == 21;
                assert MemoryBuffer.toArray(buffer, Blobify.Nat) == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20];

            },
        );

        test(
            "tabulate",
            func() {
                let buffer = MemoryBuffer.tabulate(Blobify.Nat, 10, func(i : Nat) : Nat = i);
                assert MemoryBuffer.size(buffer) == 10;
                assert MemoryBuffer.toArray(buffer, Blobify.Nat) == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
            },
        );

        test(
            "reverse",
            func() {
                let buffer = MemoryBuffer.fromArray(Blobify.Nat, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
                MemoryBuffer.reverse(buffer);

                assert MemoryBuffer.toArray(buffer, Blobify.Nat) == [9, 8, 7, 6, 5, 4, 3, 2, 1, 0];
            },
        )

    },
);
