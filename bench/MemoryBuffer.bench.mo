import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Prelude "mo:base/Prelude";

import { MemoryRegion } "mo:memory-region";

import Bench "mo:bench";

import { MemoryBuffer; Blobify } "../src";

module {
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
            "remove()",
            "insert()",
            "removeLast()"
        ]);

        let buffer = Buffer.Buffer<Nat>(8);
        let memory_buffer = MemoryBuffer.new<Nat>(null);

        let limit = 10_000;
        bench.runner(
            func(row, col) = switch (col, row) {

                case ("Buffer", "add()") {
                    for (i in Iter.range(0, limit - 1)) {
                        buffer.add(i);
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
                    for (i in Iter.range(0, limit - 1)) {
                        buffer.put(i, i * 10);
                    };
                };
                case ("Buffer", "remove()") {
                    for (_ in Iter.range(0, limit - 1)) {
                        ignore buffer.remove(0);
                    };
                };
                case ("Buffer", "insert()") {
                    for (i in Iter.range(0, limit - 1)) {
                        buffer.insert(0, i);
                    };
                };
                case ("Buffer", "removeLast()") {
                    for (_ in Iter.range(0, limit - 1)) {
                        ignore buffer.removeLast();
                    };
                };
                case ("MemoryBuffer", "add()") {
                    for (i in Iter.range(0, limit - 1)) {
                        MemoryBuffer.add(memory_buffer, Blobify.Nat, i);
                    };
                };
                case ("MemoryBuffer", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        ignore MemoryBuffer.get(memory_buffer, Blobify.Nat, i);
                    };
                };
                case ("MemoryBuffer", "put() (new == prev)") {
                    for (i in Iter.range(0, limit - 1)) {
                        MemoryBuffer.put(memory_buffer, Blobify.Nat, i, i);
                    };
                };
                case ("MemoryBuffer", "put() (new > prev)") {
                    for (i in Iter.range(0, limit - 1)) {
                        MemoryBuffer.put(memory_buffer, Blobify.Nat, i, i * 10);
                    };
                };
                case ("MemoryBuffer", "remove()") {
                    for (_ in Iter.range(0, limit - 1)) {
                        ignore MemoryBuffer.remove(memory_buffer, Blobify.Nat, 0);
                    };
                };
                case ("MemoryBuffer", "insert()") {
                    for (i in Iter.range(0, limit - 1)) {
                        MemoryBuffer.insert(memory_buffer, Blobify.Nat, 0, i * 10);
                    };
                };
                case ("MemoryBuffer", "removeLast()") {
                    for (_ in Iter.range(0, limit - 1)) {
                        ignore MemoryBuffer.removeLast(memory_buffer, Blobify.Nat);
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
