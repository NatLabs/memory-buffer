import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Prelude "mo:base/Prelude";
import RbTree "mo:base/RBTree";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Region "mo:base/Region";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";

import Bench "mo:bench";
import Fuzz "mo:fuzz";
import Map "mo:map/Map";
import MotokoStableBTree "mo:MotokoStableBTree/BTree";
import BTreeMap "mo:MotokoStableBTree/modules/btreemap";
import BTreeMapMemory "mo:MotokoStableBTree/modules/memory";

import { BpTree; Cmp } "mo:augmented-btrees";

import MemoryBTree "../../src/MemoryBTree/Base";
import MemoryUtils "../../src/MemoryBTree/MemoryUtils";
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

    public func init() : Bench.Bench {
        let fuzz = Fuzz.fromSeed(0xdeadbeef);

        let bench = Bench.Bench();
        bench.name("Comparing RBTree, BTree and B+Tree (BpTree)");
        bench.description("Benchmarking the performance with 10k entries");

        bench.rows([
            "B+Tree",
            "MotokoStableBTree",
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

        let tconv_20 = tconv(20);

        let bptree = BpTree.new<Text, Text>(?32);
        let stable_btree = BTreeMap.new<Text, Text>(BTreeMapMemory.RegionMemory(Region.new()), tconv_20, tconv_20);
        let mem_btree_no_cache = MemoryBTree.new(?32, ?0);
        let mem_btree_1_percent = MemoryBTree.new(?32, ?5);
        let mem_btree_10_percent = MemoryBTree.new(?32, ?50);
        let mem_btree_50_percent = MemoryBTree.new(?32, ?250);
        let mem_btree = MemoryBTree.new(?32, ?500);

        let entries = Buffer.Buffer<(Text, Text)>(limit);
        // let replacements = Buffer.Buffer<(Text, Text)>(limit);

        for (i in Iter.range(0, limit - 1)) {
            let key = fuzz.text.randomAlphabetic(3);

            entries.add((key, key));

            // let replace_val = fuzz.text.randomAlphabetic(10);

            // replacements.add((key, key));
        };

        let sorted = Buffer.clone(entries);
        sorted.sort(func(a, b) = Text.compare(a.0, b.0));

        func run_bench(name : Text, category : Text, mem_btree : MemoryBTree) {
            switch (category) {
                case ("insert()") {
                    for ((key, val) in entries.vals()) {
                        ignore MemoryBTree.insert<Text, Text>(mem_btree, MemoryUtils.Text, key, val);
                    };
                };
                case ("replace()") {
                    for ((key, val) in entries.vals()) {
                        ignore MemoryBTree.insert(mem_btree, MemoryUtils.Text, key, val);
                    };
                };
                case ("get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        let (key, val) = entries.get(i);
                        assert ?val == MemoryBTree.get(mem_btree, MemoryUtils.Text, key);
                    };
                };
                case ("entries()") {
                    for (kv in MemoryBTree.entries(mem_btree, MemoryUtils.Text)) {
                        ignore kv;
                    };
                };
                case ("scan()") {};
                case ("remove()") {
                    for ((k, v) in entries.vals()) {
                        ignore MemoryBTree.remove(mem_btree, MemoryUtils.Text, k);
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
                        ignore BpTree.insert(bptree, Cmp.Text, key, val);
                    };
                };
                case ("B+Tree", "replace()") {
                    for ((key, val) in entries.vals()) {
                        ignore BpTree.insert(bptree, Cmp.Text, key, val);
                    };
                };
                case ("B+Tree", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        let key = entries.get(i).0;
                        ignore BpTree.get(bptree, Cmp.Text, key);
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

                        for (kv in BpTree.scan(bptree, Cmp.Text, ?a, ?b)) {
                            ignore kv;
                        };
                        i += 100;
                    };
                };
                case ("B+Tree", "remove()") {
                    for ((k, v) in entries.vals()) {
                        ignore BpTree.remove(bptree, Cmp.Text, k);
                    };
                };

                case ("MotokoStableBTree", "insert()") {
                    for ((key, val) in entries.vals()) {
                        ignore stable_btree.insert(key, tconv_20, val, tconv_20);
                    };
                };
                case ("MotokoStableBTree", "replace()") {
                    for ((key, val) in entries.vals()) {
                        ignore stable_btree.insert(key, tconv_20, val, tconv_20);
                    };
                };
                case ("MotokoStableBTree", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        let (key, val) = entries.get(i);
                        ignore stable_btree.get(key, tconv_20, tconv_20);
                    };
                };
                case ("MotokoStableBTree", "entries()") {
                    var i = 0;
                    for (kv in stable_btree.iter(tconv_20, tconv_20)) {
                        i += 1;
                    };

                    assert Nat64.fromNat(i) == stable_btree.getLength();
                    Debug.print("Size: " # debug_show (i, stable_btree.getLength()));
                };
                case ("MotokoStableBTree", "scan()") {};
                case ("MotokoStableBTree", "remove()") {
                    for ((k, v) in entries.vals()) {
                        ignore stable_btree.remove(k, tconv_20, tconv_20);
                    };
                };

                case ("Memory B+Tree (no cache)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_no_cache);
                };
                case ("Memory B+Tree (1% cache)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_1_percent);
                };
                case ("Memory B+Tree (10% cache)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_10_percent);
                };
                case ("Memory B+Tree (50% cache)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_50_percent);
                };
                case ("Memory B+Tree (100% cache)", category) {
                    run_bench("Memory B+Tree", category, mem_btree);
                };

                case (_) {
                    Debug.trap("Should not reach with row = " # debug_show row # " and col = " # debug_show col);
                };
            }
        );

        bench;
    };
};
