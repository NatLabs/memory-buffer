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

    public func init() : Bench.Bench {
        let fuzz = Fuzz.fromSeed(0xdeadbeef);

        let bench = Bench.Bench();
        bench.name("Comparing RBTree, BTree and B+Tree (BpTree)");
        bench.description("Benchmarking the performance with 10k entries");

        bench.rows([
            "B+Tree",
            "MotokoStableBTree",
            "Memory B+Tree (order 4)",
            "Memory B+Tree (order 32)",
            "Memory B+Tree (order 64)",
            "Memory B+Tree (order 128)",
            "Memory B+Tree (order 256)",
            "Memory B+Tree (order 512)",
            "Memory B+Tree (order 1024)",
            "Memory B+Tree (order 2048)",
            "Memory B+Tree (order 4096)",
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

        let bptree = BpTree.new<Text, Text>(?32);
        let stable_btree = BTreeMap.new<Text, Text>(BTreeMapMemory.RegionMemory(Region.new()), tconv_10, tconv_10);
        let mem_btree_order_4 = MemoryBTree.new(?4);
        let mem_btree_order_32 = MemoryBTree.new(?32);
        let mem_btree_order_64 = MemoryBTree.new(?64);
        let mem_btree_order_128 = MemoryBTree.new(?128);
        let mem_btree_order_256 = MemoryBTree.new(?256);
        let mem_btree_order_512 = MemoryBTree.new(?512);
        let mem_btree_order_1024 = MemoryBTree.new(?1024);
        let mem_btree_order_2048 = MemoryBTree.new(?2048);
        let mem_btree_order_4096 = MemoryBTree.new(?4096);

        let entries = Buffer.Buffer<(Text, Text)>(limit);
        // let replacements = Buffer.Buffer<(Text, Text)>(limit);

        for (i in Iter.range(0, limit - 1)) {
            let key = fuzz.text.randomAlphabetic(10);

            entries.add((key, key));

            // let replace_val = fuzz.text.randomAlphabetic(10);

            // replacements.add((key, key));
        };

        let sorted = Buffer.clone(entries);
        sorted.sort(func(a, b) = Text.compare(a.0, b.0));

        let btree_utils = BTreeUtils.createUtils(BTreeUtils.Text, BTreeUtils.Text);

        func run_bench(name : Text, category : Text, mem_btree_order_512 : MemoryBTree) {
            switch (category) {
                case ("insert()") {
                    for ((key, val) in entries.vals()) {
                        ignore MemoryBTree.insert<Text, Text>(mem_btree_order_512, btree_utils, key, val);
                    };
                };
                case ("replace()") {
                    for ((key, val) in entries.vals()) {
                        ignore MemoryBTree.insert(mem_btree_order_512, btree_utils, key, val);
                    };
                };
                case ("get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        let (key, val) = entries.get(i);
                        assert ?val == MemoryBTree.get(mem_btree_order_512, btree_utils, key);
                    };
                };
                case ("entries()") {
                    for (kv in MemoryBTree.entries(mem_btree_order_512, btree_utils)) {
                        ignore kv;
                    };
                };
                case ("scan()") {};
                case ("remove()") {
                    for ((k, v) in entries.vals()) {
                        ignore MemoryBTree.remove(mem_btree_order_512, btree_utils, k);
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
                        ignore stable_btree.insert(key, tconv_10, val, tconv_10);
                    };
                };
                case ("MotokoStableBTree", "replace()") {
                    for ((key, val) in entries.vals()) {
                        ignore stable_btree.insert(key, tconv_10, val, tconv_10);
                    };
                };
                case ("MotokoStableBTree", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        let (key, val) = entries.get(i);
                        ignore stable_btree.get(key, tconv_10, tconv_10);
                    };
                };
                case ("MotokoStableBTree", "entries()") {
                    var i = 0;
                    for (kv in stable_btree.iter(tconv_10, tconv_10)) {
                        i += 1;
                    };

                    assert Nat64.fromNat(i) == stable_btree.getLength();
                    Debug.print("Size: " # debug_show (i, stable_btree.getLength()));
                };
                case ("MotokoStableBTree", "scan()") {};
                case ("MotokoStableBTree", "remove()") {
                    for ((k, v) in entries.vals()) {
                        ignore stable_btree.remove(k, tconv_10, tconv_10);
                    };
                };

                case ("Memory B+Tree (order 4)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_order_4);
                };
                case ("Memory B+Tree (order 32)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_order_32);
                };
                case ("Memory B+Tree (order 64)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_order_64);
                };
                case ("Memory B+Tree (order 128)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_order_128);
                };
                case ("Memory B+Tree (order 256)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_order_256);
                };
                case ("Memory B+Tree (order 512)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_order_512);
                };
                case ("Memory B+Tree (order 1024)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_order_1024);
                };
                case ("Memory B+Tree (order 2048)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_order_2048);
                };
                case ("Memory B+Tree (order 4096)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_order_4096);
                };

                case (_) {
                    Debug.trap("Should not reach with row = " # debug_show row # " and col = " # debug_show col);
                };
            }
        );

        bench;
    };
};
