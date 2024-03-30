import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Prelude "mo:base/Prelude";
import RbTree "mo:base/RBTree";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Buffer "mo:base/Buffer";

import Bench "mo:bench";
import Fuzz "mo:fuzz";
import BTree "mo:stableheapbtreemap/BTree";
import Map "mo:map/Map";
import MotokoStableBTree "mo:MotokoStableBTree/BTree";

import { BpTree; Cmp } "mo:augmented-btrees";

import MemoryBTree "../../src/MemoryBTree/Base";
import MemoryUtils "../../src/MemoryBTree/MemoryUtils";
import MemoryCmp "../../src/MemoryCmp";
import Blobify "../../src/Blobify";

module {

    public func init() : Bench.Bench {
        let fuzz = Fuzz.fromSeed(0xdeadbeef);

        let bench = Bench.Bench();
        bench.name("Comparing RBTree, BTree and B+Tree (BpTree)");
        bench.description("Benchmarking the performance with 10k entries");

        bench.cols(["B+Tree", "MotokoStableBTree", "Memory B+Tree"]);
        bench.rows([
            "insert()",
            "get()",
            "replace()",
            // "entries()",
            // "scan()",
            // "remove()",
        ]);

        let limit = 100_000;

        let { n64conv } = MotokoStableBTree;

        let bptree = BpTree.new<Nat, Nat>(?32);
        let stable_btree = MotokoStableBTree.new<Nat64, Nat64>(n64conv, n64conv);
        let mem_btree = MemoryBTree.new(?32);

        let entries = Buffer.Buffer<(Nat, Nat)>(limit);
        let n64_entries = Buffer.Buffer<(Nat64, Nat64)>(limit);

        let replacements = Buffer.Buffer<(Nat, Nat)>(limit);
        let n64_replacements = Buffer.Buffer<(Nat64, Nat64)>(limit);

        for (i in Iter.range(0, limit - 1)) {
            let key = fuzz.nat.randomRange(1, limit ** 3);
            let val = fuzz.nat.randomRange(1, limit ** 3);

            entries.add((key, val));
            n64_entries.add((Nat64.fromNat(key), Nat64.fromNat(val)));

            let replace_val = fuzz.nat.randomRange(1, limit ** 3);

            replacements.add((key, replace_val));
            n64_replacements.add((Nat64.fromNat(key), Nat64.fromNat(replace_val)));
        };

        let sorted = Buffer.clone(entries);
        sorted.sort(func(a, b) = Nat.compare(a.0, b.0));

        bench.runner(
            func(row, col) = switch (col, row) {
                

                case ("B+Tree", "insert()") {
                    for ((key, val) in entries.vals()) {
                        ignore BpTree.insert(bptree, Cmp.Nat, key, val);
                    };
                };
                case ("B+Tree", "replace()") {
                    for ((key, val) in replacements.vals()) {
                        ignore BpTree.insert(bptree, Cmp.Nat, key, val);
                    };
                };
                case ("B+Tree", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        let key = entries.get(i).0;
                        ignore BpTree.get(bptree, Cmp.Nat, key);
                    };
                };
                case ("B+Tree", "entries()") {
                    for (kv in BpTree.entries(bptree)) { ignore kv };
                };
                case ("B+Tree", "scan()") {
                    var i = 0;

                    while (i < limit) {
                        let a = sorted.get(i).0;
                        let b = sorted.get(i + 99).0;

                        for (kv in BpTree.scan(bptree, Cmp.Nat, ?a, ?b)) {
                            ignore kv;
                        };
                        i += 100;
                    };
                };
                case ("B+Tree", "remove()") {
                    for ((k, v) in entries.vals()) {
                        ignore BpTree.remove(bptree, Cmp.Nat, k);
                    };
                };

                case ("MotokoStableBTree", "insert()") {
                    for ((key, val) in n64_entries.vals()) {
                        ignore MotokoStableBTree.put<Nat64, Nat64>(stable_btree, n64conv, key, n64conv, val);
                    };
                };
                case ("MotokoStableBTree", "replace()") {
                    for ((key, val) in n64_replacements.vals()) {
                        ignore MotokoStableBTree.put<Nat64, Nat64>(stable_btree, n64conv, key, n64conv, val);
                    };
                };
                case ("MotokoStableBTree", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        let key = n64_entries.get(i).0;
                        ignore MotokoStableBTree.get<Nat64, Nat64>(stable_btree, n64conv, key, n64conv);
                    };
                };
                case ("MotokoStableBTree", "entries()") {
                };
                case ("MotokoStableBTree", "scan()") {
                };
                case ("BTree", "remove()") {
                };

                case ("Memory B+Tree", "insert()") {
                    for ((key, val) in entries.vals()) {
                        ignore MemoryBTree.insert(mem_btree, MemoryUtils.Nat, key, val);
                    };
                };
                case ("Memory B+Tree", "replace()") {
                    for ((key, val) in replacements.vals()) {
                        ignore MemoryBTree.insert(mem_btree, MemoryUtils.Nat, key, val);
                    };
                };
                case ("Memory B+Tree", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        let key = entries.get(i).0;
                        ignore MemoryBTree.get(mem_btree, MemoryUtils.Nat, key);
                    };
                };
                case ("Memory B+Tree", "entries()") {
                    // for (kv in MemoryBTree.entries(mem_btree)) { ignore kv };
                };
                case ("Memory B+Tree", "scan()") {
                    // var i = 0;

                    // while (i < limit) {
                    //     let a = sorted.get(i).0;
                    //     let b = sorted.get(i + 99).0;

                    //     for (kv in MemoryBTree.scan(mem_btree, Cmp.Nat, a, b)) {
                    //         ignore kv;
                    //     };
                    //     i += 100;
                    // };
                };
                case ("Memory B+Tree", "remove()") {
                    // for ((k, v) in entries.vals()) {
                    //     ignore MemoryBTree.remove(mem_btree, MemoryUtils.Nat, k);
                    // };
                };

                case (_) {
                    Debug.trap("Should not reach with row = " # debug_show row # " and col = " # debug_show col);
                };
            }
        );

        bench;
    };
};
