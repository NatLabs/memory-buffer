import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Prelude "mo:base/Prelude";
import Float "mo:base/Float";

import { MemoryRegion } "mo:memory-region";

import Bench "mo:bench";
import Fuzz "mo:fuzz";

import Blobify "../../src/Blobify";
import MemoryBuffer "../../src/MemoryBuffer/Base";
import VersionedMemoryBuffer "../../src/MemoryBuffer/Versioned";
import MemoryBufferClass "../../src/MemoryBuffer/Class";

import Utils "../../src/Utils";
import MemoryCmp "../../src/MemoryCmp";
import Cmp "../../src/Int8Cmp";
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
            "MemoryBuffer (with Blobify)",
            "MemoryBuffer (encode to candid)"
        ]);
        bench.rows([
            "add()",
            // "get()",
            // "put() (new == prev)",
            // "put() (new < prev)",
            // "add() reallocation",
            // "removeLast()",
            // "reverse()",
            // "remove()",
            // "insert()",
            "sortUnstable()",
            "shuffle()",
            "sortUnstable() (#blob_cmp)",
        ]);

        let limit = 10_000;

        let fuzz = Fuzz.fromSeed(0x7f7f);

        let buffer = Buffer.Buffer<Nat>(limit);
        let mbuffer = MemoryBuffer.new<Nat>();
        let cbuffer = MemoryBuffer.new<Nat>();
        
        let order = Buffer.Buffer<Nat>(limit);
        let values = Buffer.Buffer<Nat>(limit);
        let values2 = Buffer.Buffer<Nat>(limit);
        let greater = Buffer.Buffer<Nat>(limit);
        let less = Buffer.Buffer<Nat>(limit);

        func logn(number : Float, base : Float) : Float {
            Float.log(number) / Float.log(base);
        };

        for (i in Iter.range(0, limit - 1)) {
            let n1 = fuzz.nat.randomRange(0, limit ** 2);
            let n2 = fuzz.nat.randomRange(0, limit ** 2);

            order.add(i);
            values.add(n1);
            values2.add(n2);
            greater.add(n1 ** 2);

            let log : Nat = logn(Float.fromInt(n1), 2) 
                |> Float.toInt(_) 
                |> Int.abs(_);
            less.add(log);
        };

        fuzz.buffer.shuffle(order);

        bench.runner(
            func(row, col) = switch (col, row) {

                case ("Buffer", "add()" or "add() reallocation") {
                    for (i in Iter.range(0, limit - 1)) {
                        let val = values.get(i);
                        buffer.add(val);
                    };
                };
                case ("Buffer", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        ignore buffer.get(i);
                    };
                };
                case ("Buffer", "put() (new == prev)") {
                    for (i in Iter.range(0, limit - 1)) {
                        let val = values2.get(i);
                        buffer.put(i, val);
                    };
                };
                case ("Buffer", "put() (new > prev)") {
                    for (i in order.vals()) {
                        let val = greater.get(i);
                        buffer.put(i, val);
                    };
                };
                case ("Buffer", "put() (new < prev)") {
                    for (i in order.vals()) {
                        let val = less.get(i);
                        buffer.put(i, val);
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
                case ("Buffer", "reverse()") {
                    Buffer.reverse(buffer);
                };
                case ("Buffer", "sortUnstable()") {
                    buffer.sort(Nat.compare);
                };
                case ("Buffer", "sortUnstable() (#blob_cmp)") { };
                case ("Buffer", "shuffle()") {
                    // fuzz.buffer.shuffle(buffer);
                };
                case ("Buffer", "removeLast()") {
                    for (_ in Iter.range(0, limit - 1)) {
                        ignore buffer.removeLast();
                    };
                };

                case ("MemoryBuffer (encode to candid)", "add()" or "add() reallocation") {
                    for (i in Iter.range(0, limit - 1)) {
                        let val = values.get(i);
                        MemoryBuffer.add(cbuffer, candid_blobify, val);
                    };
                    Debug.print("cbuffer bytes: " # debug_show MemoryBuffer.bytes(cbuffer));
                    Debug.print("cbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(cbuffer));
                    Debug.print("cbuffer capacity: " # debug_show MemoryBuffer.capacity(cbuffer));
                    Debug.print("cbuffer metadataCapacity: " # debug_show MemoryBuffer.metadataCapacity(cbuffer));

                };
                case ("MemoryBuffer (encode to candid)", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        ignore MemoryBuffer.get(cbuffer, candid_blobify, i);
                    };
                    
                };
                case ("MemoryBuffer (encode to candid)", "put() (new == prev)") {
                    for (i in order.vals()) {
                        let val = values2.get(i);
                        MemoryBuffer.put(cbuffer, candid_blobify, i, val);
                    };
                    Debug.print("cbuffer bytes: " # debug_show MemoryBuffer.bytes(cbuffer));
                    Debug.print("cbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(cbuffer));
                    Debug.print("cbuffer capacity: " # debug_show MemoryBuffer.capacity(cbuffer));
                    Debug.print("cbuffer metadataCapacity: " # debug_show MemoryBuffer.metadataCapacity(cbuffer));

                };
                case ("MemoryBuffer (encode to candid)", "put() (new > prev)") {
                    for (i in order.vals()) {
                        let val = greater.get(i);
                        MemoryBuffer.put(cbuffer, candid_blobify, i, val);
                    };
                    Debug.print("cbuffer bytes: " # debug_show MemoryBuffer.bytes(cbuffer));
                    Debug.print("cbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(cbuffer));
                    Debug.print("cbuffer capacity: " # debug_show MemoryBuffer.capacity(cbuffer));
                    Debug.print("cbuffer metadataCapacity: " # debug_show MemoryBuffer.metadataCapacity(cbuffer));

                };
                case ("MemoryBuffer (encode to candid)", "put() (new < prev)") {
                    for (i in order.vals()) {
                        let val = less.get(i);
                        MemoryBuffer.put(cbuffer, candid_blobify, i, val);
                    };
                    Debug.print("cbuffer bytes: " # debug_show MemoryBuffer.bytes(cbuffer));
                    Debug.print("cbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(cbuffer));
                    Debug.print("cbuffer capacity: " # debug_show MemoryBuffer.capacity(cbuffer));
                    Debug.print("cbuffer metadataCapacity: " # debug_show MemoryBuffer.metadataCapacity(cbuffer));

                };
                case ("MemoryBuffer (encode to candid)", "remove()") {
                    for (i in order.vals()) {
                        let j = Nat.min(i, MemoryBuffer.size(cbuffer) - 1);

                        ignore MemoryBuffer.remove(cbuffer, candid_blobify, j);
                    };
                    Debug.print("cbuffer bytes: " # debug_show MemoryBuffer.bytes(cbuffer));
                    Debug.print("cbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(cbuffer));
                    Debug.print("cbuffer capacity: " # debug_show MemoryBuffer.capacity(cbuffer));
                    Debug.print("cbuffer metadataCapacity: " # debug_show MemoryBuffer.metadataCapacity(cbuffer));

                };
                case ("MemoryBuffer (encode to candid)", "insert()") {
                    for (i in order.vals()) {
                        MemoryBuffer.insert(cbuffer, candid_blobify, Nat.min(i, MemoryBuffer.size(cbuffer)), i ** 3);
                    };
                };
                case("MemoryBuffer (encode to candid)", "reverse()") {
                    MemoryBuffer.reverse(cbuffer);
                };
                case("MemoryBuffer (encode to candid)", "sortUnstable()") {
                    MemoryBuffer.sortUnstable(cbuffer, candid_blobify, #cmp(Cmp.Nat));
                };
                case("MemoryBuffer (encode to candid)", "sortUnstable() (#blob_cmp)") {};
                case ("MemoryBuffer (encode to candid)", "shuffle()") {
                    MemoryBuffer.shuffle(cbuffer);
                };
                case ("MemoryBuffer (encode to candid)", "removeLast()") {
                    for (_ in Iter.range(0, limit - 1)) {
                        ignore MemoryBuffer.removeLast(cbuffer, candid_blobify);
                    };
                };
                
                case ("MemoryBuffer (with Blobify)", "add()" or "add() reallocation") {
                    for (i in Iter.range(0, limit - 1)) {
                        let val = values.get(i);
                        MemoryBuffer.add(mbuffer, Blobify.BigEndian.Nat, val);
                    };

                    Debug.print("mbuffer bytes: " # debug_show MemoryBuffer.bytes(mbuffer));
                    Debug.print("mbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(mbuffer));
                    Debug.print("mbuffer capacity: " # debug_show MemoryBuffer.capacity(mbuffer));
                    Debug.print("mbuffer metadataCapacity: " # debug_show MemoryBuffer.metadataCapacity(mbuffer));

                };
                case ("MemoryBuffer (with Blobify)", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        ignore MemoryBuffer.get(mbuffer, Blobify.BigEndian.Nat, i);
                    };
                    
                };
                case ("MemoryBuffer (with Blobify)", "put() (new == prev)") {
                    for (i in order.vals()) {
                        let val = values2.get(i);
                        MemoryBuffer.put(mbuffer, Blobify.BigEndian.Nat, i, val);
                    };
                    Debug.print("mbuffer bytes: " # debug_show MemoryBuffer.bytes(mbuffer));
                    Debug.print("mbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(mbuffer));
                    Debug.print("mbuffer capacity: " # debug_show MemoryBuffer.capacity(mbuffer));
                    Debug.print("mbuffer metadataCapacity: " # debug_show MemoryBuffer.metadataCapacity(mbuffer));

                };
                case ("MemoryBuffer (with Blobify)", "put() (new > prev)") {
                    for (i in order.vals()) {
                        let val = greater.get(i);
                        MemoryBuffer.put(mbuffer, Blobify.BigEndian.Nat, i, val);
                    };
                    Debug.print("mbuffer bytes: " # debug_show MemoryBuffer.bytes(mbuffer));
                    Debug.print("mbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(mbuffer));
                    Debug.print("mbuffer capacity: " # debug_show MemoryBuffer.capacity(mbuffer));
                    Debug.print("mbuffer metadataCapacity: " # debug_show MemoryBuffer.metadataCapacity(mbuffer));

                };
                case ("MemoryBuffer (with Blobify)", "put() (new < prev)") {
                    for (i in order.vals()) {
                        let val = less.get(i);
                        MemoryBuffer.put(mbuffer, Blobify.BigEndian.Nat, i, val);
                    };
                    Debug.print("mbuffer bytes: " # debug_show MemoryBuffer.bytes(mbuffer));
                    Debug.print("mbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(mbuffer));
                    Debug.print("mbuffer capacity: " # debug_show MemoryBuffer.capacity(mbuffer));
                    Debug.print("mbuffer metadataCapacity: " # debug_show MemoryBuffer.metadataCapacity(mbuffer));

                };
                case ("MemoryBuffer (with Blobify)", "remove()") {
                    for (i in order.vals()) {
                        let j = Nat.min(i, MemoryBuffer.size(mbuffer) - 1);

                        ignore MemoryBuffer.remove(mbuffer, Blobify.BigEndian.Nat, j);
                    };
                    Debug.print("mbuffer bytes: " # debug_show MemoryBuffer.bytes(mbuffer));
                    Debug.print("mbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(mbuffer));
                    Debug.print("mbuffer capacity: " # debug_show MemoryBuffer.capacity(mbuffer));
                    Debug.print("mbuffer metadataCapacity: " # debug_show MemoryBuffer.metadataCapacity(mbuffer));

                };
                case ("MemoryBuffer (with Blobify)", "insert()") {
                    for (i in order.vals()) {
                        MemoryBuffer.insert(mbuffer, Blobify.BigEndian.Nat, Nat.min(i, MemoryBuffer.size(mbuffer)), i ** 3);
                    };
                };
                case("MemoryBuffer (with Blobify)", "reverse()") {
                    MemoryBuffer.reverse(mbuffer);
                };
                case("MemoryBuffer (with Blobify)", "sortUnstable()") {
                    MemoryBuffer.sortUnstable(mbuffer, Blobify.BigEndian.Nat, #cmp(Cmp.Nat));
                };
                case("MemoryBuffer (with Blobify)", "shuffle()") {
                    MemoryBuffer.shuffle(mbuffer);
                };
                case("MemoryBuffer (with Blobify)", "sortUnstable() (#blob_cmp)") {
                    MemoryBuffer.sortUnstable(mbuffer, Blobify.BigEndian.Nat, #blob_cmp(Cmp.Blob));
                };
                case ("MemoryBuffer (with Blobify)", "removeLast()") {
                    for (_ in Iter.range(0, limit - 1)) {
                        ignore MemoryBuffer.removeLast(mbuffer, Blobify.BigEndian.Nat);
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
