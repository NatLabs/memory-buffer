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

    public func init() : Bench.Bench {
        let fuzz = Fuzz.fromSeed(0xdeadbeef);

        let bench = Bench.Bench();
        bench.name("Comparing RBTree, BTree and B+Tree (BpTree)");
        bench.description("Benchmarking the performance with 10k entries");

        bench.cols(["B+Tree", "MotokoStableBTree", "Memory B+Tree (with Blobify)", "Memory B+Tree (encode to candid)"]);
        bench.rows([
            "insert()",
            "get()",
            "replace()",
            "entries()",
            // "scan()",
            // "remove()",
        ]);

        let limit = 10_000;

        let { n64conv; tconv } = MotokoStableBTree;

        let tconv_20 = tconv(20);

        let bptree = BpTree.new<Text, Text>(?32);
        let stable_btree = BTreeMap.new<Text, Text>(BTreeMapMemory.RegionMemory(Region.new()), tconv_20, tconv_20);
        let mem_btree = MemoryBTree.new(?32);
        let candid_mem_btree = MemoryBTree.new(?32);

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

        bench.runner(
            func(row, col) = switch (col, row) {

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

                case ("Memory B+Tree (with Blobify)", "insert()") {
                    for ((key, val) in entries.vals()) {
                        ignore MemoryBTree.insert<Text, Text>(mem_btree, MemoryUtils.Text, key, val);
                    };
                };
                case ("Memory B+Tree (with Blobify)", "replace()") {
                    for ((key, val) in entries.vals()) {
                        ignore MemoryBTree.insert(mem_btree, MemoryUtils.Text, key, val);
                    };
                };
                case ("Memory B+Tree (with Blobify)", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        let (key, val) = entries.get(i);
                        assert ?val ==  MemoryBTree.get(mem_btree, MemoryUtils.Text, key);
                    };
                };
                case ("Memory B+Tree (with Blobify)", "entries()") {
                    for (kv in MemoryBTree.entries(mem_btree, MemoryUtils.Text)) {
                        ignore kv;
                    };
                };
                case ("Memory B+Tree (with Blobify)", "scan()") {
                };
                case ("Memory B+Tree (with Blobify)", "remove()") {
                 
                };

                case ("Memory B+Tree (encode to candid)", "insert()") {
                    for ((key, val) in entries.vals()) {
                        ignore MemoryBTree.insert(candid_mem_btree, candid_mem_utils, key, val);
                    };
                };
                case ("Memory B+Tree (encode to candid)", "replace()") {
                    for ((key, val) in entries.vals()) {
                        ignore MemoryBTree.insert(candid_mem_btree, candid_mem_utils, key, val);
                    };
                };
                case ("Memory B+Tree (encode to candid)", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        let key = entries.get(i).0;
                        ignore MemoryBTree.get(candid_mem_btree, candid_mem_utils, key);
                    };
                };
                case ("Memory B+Tree (encode to candid)", "entries()") {
                    var i = 0;
                    for (kv in MemoryBTree.entries(candid_mem_btree, candid_mem_utils)) {
                        i += 1;
                    };

                    Debug.print("Size: " # debug_show (i, MemoryBTree.size(candid_mem_btree)));
                    assert i == MemoryBTree.size(candid_mem_btree);
                };
                case ("Memory B+Tree (encode to candid)", "scan()") {
                };
                case ("Memory B+Tree (encode to candid)", "remove()") {
                 
                };

                case (_) {
                    Debug.trap("Should not reach with row = " # debug_show row # " and col = " # debug_show col);
                };
            }
        );

        bench;
    };
};
