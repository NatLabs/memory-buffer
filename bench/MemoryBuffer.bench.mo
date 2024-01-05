import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Prelude "mo:base/Prelude";

import { MemoryRegion } "mo:memory-region";

import Bench "mo:bench";
import Fuzz "mo:fuzz";

import { MemoryBuffer; Blobify } "../src";
import Utils "../src/Utils";
module {

    let candid_blobify : Blobify.Blobify<Nat> = {
        from_blob = func(b: Blob) : Nat {
            let ?n: ?Nat = from_candid(b) else {
                Debug.trap("Failed to decode Nat from blob");
            };
            n;
        };
        to_blob = func(n: Nat) : Blob = to_candid(n);
    };

    public func init() : Bench.Bench {
        let bench = Bench.Bench();

        bench.name("Buffer vs MemoryBuffer");
        bench.description("Benchmarking the performance with 10k entries");

        bench.cols([
            "Buffer",
            "MemoryBuffer",
            // "MemoryBuffer (with cache)"
        ]);
        bench.rows([
            "add()",
            "get()",
            "put() (new == prev)",
            "put() (new > prev)",
            "put() (new < prev)",
            "remove()",
            "insert()",
            "removeLast()",
        ]);

        let limit = 10_000;

        let fuzz = Fuzz.fromSeed(0x7f7f);

        let buffer = Buffer.Buffer<Nat>(limit);
        let memory_buffer = MemoryBuffer.new<Nat>();
        let order = Buffer.Buffer<Nat>(limit);

        for (i in Iter.range(0, limit - 1)) {
            order.add(i);
        };

        fuzz.buffer.shuffle(order);

        bench.runner(
            func(row, col) = switch (col, row) {

                case ("Buffer", "add()") {
                    for (i in Iter.range(0, limit - 1)) {
                        buffer.add(i * 10);
                    };
                };
                case ("Buffer", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        ignore buffer.get(i);
                    };
                };
                case ("Buffer", "put() (new == prev)") {
                    for (i in Iter.range(0, limit - 1)) {
                        buffer.put(i, i);
                    };
                };
                case ("Buffer", "put() (new > prev)") {
                    for (i in order.vals()) {
                        buffer.put(i, i * 100);
                    };
                };
                case ("Buffer", "put() (new < prev)") {
                    for (i in order.vals()) {
                        buffer.put(i, i);
                    };
                };
                case ("Buffer", "remove()") {
                    for (i in order.vals()) {
                        ignore buffer.remove(Nat.min(i, buffer.size() - 1));
                    };
                };
                case ("Buffer", "insert()") {
                    for (i in order.vals()) {
                        buffer.insert(Nat.min(i, buffer.size()), i);
                    };
                };
                case ("Buffer", "removeLast()") {
                    for (_ in Iter.range(0, limit - 1)) {
                        ignore buffer.removeLast();
                    };
                };

                case ("MemoryBuffer", "add()") {
                    for (i in Iter.range(0, limit - 1)) {
                        MemoryBuffer.add(memory_buffer, candid_blobify, i * 10);
                    };
                };
                case ("MemoryBuffer", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        ignore MemoryBuffer.get(memory_buffer, candid_blobify, i);
                    };
                };
                case ("MemoryBuffer", "put() (new == prev)") {
                    for (i in order.vals()) {
                        MemoryBuffer.put(memory_buffer, candid_blobify, i, i * 10);
                    };
                };
                case ("MemoryBuffer", "put() (new > prev)") {
                    for (i in order.vals()) {
                        MemoryBuffer.put(memory_buffer, candid_blobify, i, i * 100);
                    };
                };
                case ("MemoryBuffer", "put() (new < prev)") {
                    for (i in order.vals()) {
                        MemoryBuffer.put(memory_buffer, candid_blobify, i, i);
                    };
                };
                case ("MemoryBuffer", "remove()") {
                    for (i in order.vals()) {
                        ignore MemoryBuffer.remove(memory_buffer, candid_blobify, 0);
                    };
                };
                case ("MemoryBuffer", "insert()") {
                    for (i in order.vals()) {
                        MemoryBuffer.insert(memory_buffer, candid_blobify, 0, i * 100);
                    };
                };
                case ("MemoryBuffer", "removeLast()") {
                    for (_ in Iter.range(0, limit - 1)) {
                        ignore MemoryBuffer.removeLast(memory_buffer, candid_blobify);
                    };
                };
                case (_) {
                    Debug.trap("Should not reach with row = " # debug_show row # " and col = " # debug_show col);
                };
            }
        );

        bench;
    };
};
