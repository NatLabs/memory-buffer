import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Region "mo:base/Region";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";

import Bench "mo:bench";
import Fuzz "mo:fuzz";
import MotokoStableBTree "mo:MotokoStableBTree/BTree";
import BTreeMap "mo:MotokoStableBTree/modules/btreemap";
import BTreeMapMemory "mo:MotokoStableBTree/modules/memory";

import { BpTree; Cmp } "mo:augmented-btrees";

import MemoryBTree "../../src/MemoryBTree/Base";
import BTreeUtils "../../src/MemoryBTree/BTreeUtils";
import MemoryCmp "../../src/MemoryCmp";
import Blobify "../../src/Blobify";

module {

    let candid_text : Blobify.Blobify<Text> = {
        from_blob = func(b : Blob) : Text {
            let ?n : ?Text = from_candid (b) else {
                Debug.trap("Failed to decode Text from blob");
            };
            n;
        };
        to_blob = func(n : Text) : Blob = to_candid (n);
    };

    let candid_nat : Blobify.Blobify<Nat> = {
        from_blob = func(b : Blob) : Nat {
            let ?n : ?Nat = from_candid (b) else {
                Debug.trap("Failed to decode Nat from blob");
            };
            n;
        };
        to_blob = func(n : Nat) : Blob = to_candid (n);
    };

    let candid_mem_utils = (candid_text, candid_text, MemoryCmp.Default);

    type MemoryBTree = MemoryBTree.MemoryBTree;
    type BTreeUtils<K, V> = BTreeUtils.BTreeUtils<K, V>;

    public func init() : Bench.Bench {
        let fuzz = Fuzz.fromSeed(0xdeadbeef);

        let bench = Bench.Bench();
        bench.name("Comparing RBTree, BTree and B+Tree (BpTree)");
        bench.description("Benchmarking the performance with 10k entries");

        bench.rows([
            "B+Tree",
            "Memory B+Tree (no cache)",
            "Memory B+Tree (1% cache)",
            "Memory B+Tree (10% cache)",
            "Memory B+Tree (50% cache)",
            "Memory B+Tree (100% cache)",

        ]);
        bench.cols([
            "insert()",
            "get()",
            "replace()",
            "entries()",
            // "scan()",
            "remove()",
        ]);

        let limit = 10_000;

        let { n64conv; tconv } = MotokoStableBTree;

        let tconv_10 = tconv(10);

        let bptree = BpTree.new<Nat, Nat>(?32);
        let stable_btree = BTreeMap.new<Text, Text>(BTreeMapMemory.RegionMemory(Region.new()), tconv_10, tconv_10);
        let mem_btree_no_cache = MemoryBTree._new_with_options(?32, ?0, false);
        let mem_btree_1_percent = MemoryBTree._new_with_options(?32, ?100, false);
        let mem_btree_10_percent = MemoryBTree._new_with_options(?32, ?1000, false);
        let mem_btree_50_percent = MemoryBTree._new_with_options(?32, ?5_000, false);
        let mem_btree = MemoryBTree._new_with_options(?32, ?10_000, false);

        let entries = Buffer.Buffer<(Nat, Nat)>(limit);
        // let replacements = Buffer.Buffer<(Nat, Nat)>(limit);

        for (i in Iter.range(0, limit - 1)) {
            let key = fuzz.nat.randomRange(0, limit ** 2);

            entries.add((key, key));

            // let replace_val = fuzz.text.randomAlphabetic(10);

            // replacements.add((key, key));
        };

        let sorted = Buffer.clone(entries);
        sorted.sort(func(a, b) = Nat.compare(a.0, b.0));

        let btree_utils = BTreeUtils.createUtils(BTreeUtils.BigEndian.Nat, BTreeUtils.BigEndian.Nat);

        func run_bench(name : Text, category : Text, mem_btree : MemoryBTree, btree_utils : BTreeUtils<Nat, Nat>) {
            switch (category) {
                case ("insert()") {
                    for ((key, val) in entries.vals()) {
                        ignore MemoryBTree.insert<Nat, Nat>(mem_btree, btree_utils, key, val);
                    };
                };
                case ("replace()") {
                    for ((key, val) in entries.vals()) {
                        ignore MemoryBTree.insert(mem_btree, btree_utils, key, val);
                    };
                };
                case ("get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        let (key, val) = entries.get(i);
                        assert ?val == MemoryBTree.get(mem_btree, btree_utils, key);
                    };
                };
                case ("entries()") {
                    for (kv in MemoryBTree.entries(mem_btree, btree_utils)) {
                        ignore kv;
                    };
                };
                case ("scan()") {};
                case ("remove()") {
                    for ((k, v) in entries.vals()) {
                        ignore MemoryBTree.remove(mem_btree, btree_utils, k);
                    };
                };
                case (_) {
                    Debug.trap("Should not reach with name = " # debug_show name # " and category = " # debug_show category);
                };
            };
        };

        bench.runner(
            func(col, row) = switch (col, row) {

                case ("B+Tree", "insert()") {
                    for ((key, val) in entries.vals()) {
                        ignore BpTree.insert(bptree, Cmp.Nat, key, val);
                    };
                };
                case ("B+Tree", "replace()") {
                    for ((key, val) in entries.vals()) {
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

                case ("Memory B+Tree (no cache)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_no_cache, btree_utils);
                };
                case ("Memory B+Tree (1% cache)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_1_percent, btree_utils);
                };
                case ("Memory B+Tree (10% cache)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_10_percent, btree_utils);
                };
                case ("Memory B+Tree (50% cache)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_50_percent, btree_utils);
                };
                case ("Memory B+Tree (100% cache)", category) {
                    run_bench("Memory B+Tree", category, mem_btree, btree_utils);
                };

                case (_) {
                    Debug.trap("Should not reach with row = " # debug_show row # " and col = " # debug_show col);
                };
            }
        );

        bench;
    };
};
