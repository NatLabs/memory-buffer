// @testmode wasi
import { test; suite } "mo:test";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Nat32 "mo:base/Nat32";
import Nat "mo:base/Nat";
import Order "mo:base/Order";

import LruCache "mo:lru-cache";
import Fuzz "mo:fuzz";
import Itertools "mo:itertools/Iter";
import Map "mo:map/Map";

import MemoryBTree "../../src/MemoryBTree/Base";
import MemoryUtils "../../src/MemoryBTree/modules/MemoryUtils";
import Blobify "../../src/Blobify";
import MemoryCmp "../../src/MemoryCmp";
import Utils "../../src/Utils";
import Branch "../../src/MemoryBTree/modules/Branch";
import Leaf "../../src/MemoryBTree/modules/Leaf";
import Methods "../../src/MemoryBTree/modules/Methods";

type MemoryUtils<K, V> = MemoryBTree.MemoryUtils<K, V>;
type Buffer<A> = Buffer.Buffer<A>;
type Iter<A> = Iter.Iter<A>;
type Order = Order.Order;

let { nhash } = Map;
let fuzz = Fuzz.fromSeed(0xdeadbeef);

let limit = 10_000;

let nat_gen_iter : Iter<Nat> = {
    next = func() : ?Nat = ?fuzz.nat.randomRange(1, limit ** 2);
};
let unique_iter = Itertools.unique<Nat>(nat_gen_iter, Nat32.fromNat, Nat.equal);
let random = Itertools.toBuffer<(Nat, Nat)>(
    Iter.map<(Nat, Nat), (Nat, Nat)>(
        Itertools.enumerate(Itertools.take(unique_iter, limit)),
        func((i, n) : (Nat, Nat)) : (Nat, Nat) = (n, i),
    )
);

let sorted = Buffer.clone(random);
sorted.sort(func(a : (Nat, Nat), b : (Nat, Nat)) : Order = Nat.compare(a.0, b.0));

let candid_blobify : Blobify.Blobify<Nat> = {
    from_blob = func(b : Blob) : Nat {
        let ?n : ?Nat = from_candid (b) else {
            Debug.trap("Failed to decode Nat from blob");
        };
        n;
    };
    to_blob = func(n : Nat) : Blob = to_candid (n);
};

let candid_mem_utils = (candid_blobify, candid_blobify, MemoryCmp.Nat);

let btree = MemoryBTree.new(?32);

suite(
    "MemoryBTree",
    func() {
        test(
            "insert random",
            func() {
                let map = Map.new<Nat, Nat>();
                // assert btree.order == 4;

                // Debug.print("random size " # debug_show random.size());
                label for_loop for ((k, i) in random.vals()) {
                    // Debug.print("inserting " # debug_show k # " at index " # debug_show i);

                    ignore Map.put(map, nhash, k, i);
                    ignore MemoryBTree.insert(btree, MemoryUtils.Nat, k, i);
                    assert MemoryBTree.size(btree) == i + 1;

                    // Debug.print("keys " # debug_show MemoryBTree.toNodeKeys(btree, MemoryUtils.Nat));
                    // Debug.print("leafs " # debug_show MemoryBTree.toLeafNodes(btree, MemoryUtils.Nat));

                    let subtree_size = Branch.get_node_subtree_size(btree, btree.root);

                    // Debug.print("subtree_size " # debug_show subtree_size);
                    assert subtree_size == MemoryBTree.size(btree);

                    if (?i != MemoryBTree.get(btree, MemoryUtils.Nat, k)) {
                        Debug.print("mismatch: " # debug_show (k, (i, MemoryBTree.get(btree, MemoryUtils.Nat, k))) # " at index " # debug_show i);
                        assert false;
                    };

                };

                assert Methods.validate_memory(btree, MemoryUtils.Nat);

                // Debug.print("entries: " # debug_show Iter.toArray(MemoryBTree.entries(btree, MemoryUtils.Nat)));

                let entries = MemoryBTree.entries(btree, MemoryUtils.Nat);
                let entry = Utils.unwrap(entries.next(), "expected key");
                var prev = entry.0;

                for ((i, (key, val)) in Itertools.enumerate(entries)) {
                    if (prev > key) {
                        Debug.print("mismatch: " # debug_show (prev, key) # " at index " # debug_show i);
                        assert false;
                    };

                    let expected = Map.get(map, nhash, key);
                    if (expected != ?val) {
                        Debug.print("mismatch: " # debug_show (key, (expected, val)) # " at index " # debug_show (i + 1));
                        assert false;
                    };

                    if (?val != MemoryBTree.get(btree, MemoryUtils.Nat, key)) {
                        Debug.print("mismatch: " # debug_show (key, (expected, MemoryBTree.get(btree, MemoryUtils.Nat, key))) # " at index " # debug_show (i + 1));
                        assert false;
                    };

                    prev := key;
                };

                assert Methods.validate_memory(btree, MemoryUtils.Nat);
            },
        );

        test(
            "get()",
            func() {
                var i = 0;
                for ((key, val) in random.vals()) {
                    let got = MemoryBTree.get(btree, MemoryUtils.Nat, key);
                    if (?val != got) {
                        Debug.print("mismatch: " # debug_show (val, got) # " at index " # debug_show i);
                        assert false;
                    };
                    i += 1;
                };
            },
        );

        test(
            "getIndex",
            func() {

                for (i in Itertools.range(0, sorted.size())) {
                    let (key, _) = sorted.get(i);
                    // Debug.print("i = " # debug_show (i));

                    // Debug.print("key: " # debug_show key);
                    let expected = i;
                    let rank = MemoryBTree.getIndex(btree, MemoryUtils.Nat, key);
                    if (not (rank == expected)) {
                        Debug.print("mismatch for key:" # debug_show key);
                        Debug.print("expected != rank: " # debug_show (expected, rank));
                        assert false;
                    };
                };
            },
        );

        test(
            "getFromIndex",
            func() {
                for (i in Itertools.range(0, sorted.size())) {
                    let expected = sorted.get(i);
                    let received = MemoryBTree.getFromIndex(btree, MemoryUtils.Nat, i);

                    if (not ((expected, expected) == received)) {
                        Debug.print("mismatch at rank:" # debug_show i);
                        Debug.print("expected != received: " # debug_show ((expected, expected), received));
                        assert false;
                    };
                };
            },
        );

        test(
            "getFloor()",
            func() {

                for (i in Itertools.range(0, sorted.size())) {
                    let (key, _) = sorted.get(i);

                    let expected = sorted.get(i);
                    let received = MemoryBTree.getFloor(btree, MemoryUtils.Nat, key);

                    if (not (?expected == received)) {
                        Debug.print("mismatch at key:" # debug_show key);
                        Debug.print("expected != received: " # debug_show (expected, received));
                        assert false;
                    };

                    let prev = key - 1;

                    if (i > 0) {
                        let expected = sorted.get(i - 1);
                        let received = MemoryBTree.getFloor(btree, MemoryUtils.Nat, prev);

                        if (not (?(expected) == received)) {
                            Debug.print("mismatch at key:" # debug_show prev);
                            Debug.print("expected != received: " # debug_show (expected, received));
                            assert false;
                        };
                    } else {
                        assert MemoryBTree.getFloor(btree, MemoryUtils.Nat, prev) == null;
                    };

                    let next = key + 1;

                    do {
                        let expected = sorted.get(i);
                        let received = MemoryBTree.getFloor(btree, MemoryUtils.Nat, next);

                        if (not (?expected == received)) {
                            Debug.print("mismatch at key:" # debug_show next);
                            Debug.print("expected != received: " # debug_show (expected, received));
                            assert false;
                        };
                    };

                };
            },
        );

        test(
            "getCeiling()",
            func() {
                for (i in Itertools.range(0, sorted.size())) {
                    var key = sorted.get(i).0;

                    let expected = sorted.get(i);
                    let received = MemoryBTree.getCeiling<Nat, Nat>(btree, MemoryUtils.Nat, key);

                    if (not (?expected == received)) {
                        Debug.print("mismatch at key:" # debug_show key);
                        Debug.print("expected != received: " # debug_show (expected, received));
                        assert false;
                    };

                    let prev = key - 1;

                    do {
                        let expected = sorted.get(i);
                        let received = MemoryBTree.getCeiling<Nat, Nat>(btree, MemoryUtils.Nat, prev);

                        if (not (?expected == received)) {
                            Debug.print("mismatch at key:" # debug_show prev);
                            Debug.print("expected != received: " # debug_show (expected, received));
                            assert false;
                        };
                    };

                    let next = key + 1;

                    if (i + 1 < sorted.size()) {
                        let expected = sorted.get(i + 1);
                        let received = MemoryBTree.getCeiling<Nat, Nat>(btree, MemoryUtils.Nat, next);

                        if (not (?expected == received)) {
                            Debug.print("mismatch at key:" # debug_show next);
                            Debug.print("expected != received: " # debug_show (expected, received));
                            assert false;
                        };
                    } else {
                        assert MemoryBTree.getCeiling<Nat, Nat>(btree, MemoryUtils.Nat, next) == null;
                    };

                };
            },
        );
        test(
            "entries()",
            func() {
                var i = 0;
                for ((a, b) in Itertools.zip(MemoryBTree.entries(btree, MemoryUtils.Nat), sorted.vals())) {
                    if (a != b) {
                        Debug.print("mismatch: " # debug_show (a, b) # " at index " # debug_show i);
                        assert false;
                    };
                    i += 1;
                };

                assert i == sorted.size();

                assert Methods.validate_memory(btree, MemoryUtils.Nat);

            },
        );

        test(
            "scan",
            func() {
                let sliding_tuples = Itertools.range(0, MemoryBTree.size(btree))
                |> Iter.map<Nat, Nat>(_, func(n : Nat) : Nat = n * 100)
                |> Itertools.takeWhile(_, func(n : Nat) : Bool = n < MemoryBTree.size(btree))
                |> Itertools.slidingTuples(_);

                for ((i, j) in sliding_tuples) {
                    let start_key = sorted.get(i).0;
                    let end_key = sorted.get(j).0;

                    var index = i;

                    for ((k, v) in MemoryBTree.scan<Nat, Nat>(btree, MemoryUtils.Nat, ?start_key, ?end_key)) {
                        let expected = sorted.get(index).0;

                        if (not (expected == k)) {
                            Debug.print("mismatch: " # debug_show (expected, k));
                            Debug.print("scan " # debug_show Iter.toArray(MemoryBTree.scan(btree, MemoryUtils.Nat, ?start_key, ?end_key)));

                            let expected_vals = Iter.range(i, j)
                            |> Iter.map<Nat, Nat>(_, func(n : Nat) : Nat = sorted.get(n).1);
                            Debug.print("expected " # debug_show Iter.toArray(expected_vals));
                            assert false;
                        };

                        index += 1;
                    };
                };
            },
        );

        test(
            "range",
            func() {
                let sliding_tuples = Itertools.range(0, MemoryBTree.size(btree))
                |> Iter.map<Nat, Nat>(_, func(n : Nat) : Nat = n * 100)
                |> Itertools.takeWhile(_, func(n : Nat) : Bool = n < MemoryBTree.size(btree))
                |> Itertools.slidingTuples(_);

                let sorted_array = Buffer.toArray(sorted);

                for ((i, j) in sliding_tuples) {

                    if (
                        not Itertools.equal<(Nat, Nat)>(
                            MemoryBTree.range(btree, MemoryUtils.Nat, i, j),
                            Itertools.fromArraySlice<(Nat, Nat)>(sorted_array, i, j + 1),
                            func(a : (Nat, Nat), b : (Nat, Nat)) : Bool = a == b,
                        )
                    ) {
                        Debug.print("mismatch: " # debug_show (i, j));
                        Debug.print("range " # debug_show Iter.toArray(MemoryBTree.range(btree, MemoryUtils.Nat, i, j)));
                        Debug.print("expected " # debug_show Iter.toArray(Itertools.fromArraySlice(sorted_array, i, j + 1)));
                        assert false;
                    };
                };
            },
        );

        test(
            "replace",
            func() {

                for ((key, i) in random.vals()) {
                    let prev_val = i;
                    let new_val = prev_val * 10;

                    assert ?prev_val == MemoryBTree.insert<Nat, Nat>(btree, MemoryUtils.Nat, key, new_val);
                    assert ?new_val == MemoryBTree.get(btree, MemoryUtils.Nat, key);
                };

                assert Methods.validate_memory(btree, MemoryUtils.Nat);

            },
        );

        test(
            "remove() random",
            func() {

                // Debug.print("node keys: " # debug_show MemoryBTree.toNodeKeys(btree, MemoryUtils.Nat));
                // Debug.print("leaf nodes: " # debug_show MemoryBTree.toLeafNodes(btree, MemoryUtils.Nat));

                for ((key, i) in random.vals()) {
                    // Debug.print("removing " # debug_show key);
                    let val = MemoryBTree.remove(btree, MemoryUtils.Nat, key);
                    // Debug.print("(i, val): " # debug_show (i, val));
                    assert ?(i * 10) == val;

                    assert MemoryBTree.size(btree) == random.size() - i - 1;
                    // Debug.print("node keys: " # debug_show MemoryBTree.toNodeKeys(btree, MemoryUtils.Nat));
                    // Debug.print("leaf nodes: " # debug_show Iter.toArray(MemoryBTree.leafNodes(btree, MemoryUtils.Nat)));

                };

                assert Methods.validate_memory(btree, MemoryUtils.Nat);

            },

        );

        test(
            "clear()",
            func() {
                MemoryBTree.clear(btree);
                assert MemoryBTree.size(btree) == 0;

                assert Methods.validate_memory(btree, MemoryUtils.Nat);

                MemoryBTree.clear(btree);
                assert MemoryBTree.size(btree) == 0;

                assert Methods.validate_memory(btree, MemoryUtils.Nat);
            },
        );

        test(
            "insert random",
            func() {
                let map = Map.new<Nat, Nat>();
                // assert btree.order == 4;

                // Debug.print("random size " # debug_show random.size());
                label for_loop for ((k, i) in random.vals()) {

                    ignore Map.put(map, nhash, k, i);
                    ignore MemoryBTree.insert(btree, MemoryUtils.Nat, k, i);
                    assert MemoryBTree.size(btree) == i + 1;

                    // Debug.print("keys " # debug_show MemoryBTree.toNodeKeys(btree));
                    // Debug.print("leafs " # debug_show MemoryBTree.toLeafNodes(btree));

                    let subtree_size = Branch.get_node_subtree_size(btree, btree.root);

                    assert subtree_size == MemoryBTree.size(btree);

                    if (?i != MemoryBTree.get(btree, MemoryUtils.Nat, k)) {
                        Debug.print("mismatch: " # debug_show (k, (i, MemoryBTree.get(btree, MemoryUtils.Nat, k))) # " at index " # debug_show i);
                        assert false;
                    };
                };

                // Debug.print("entries: " # debug_show Iter.toArray(MemoryBTree.entries(btree, MemoryUtils.Nat)));

                let entries = MemoryBTree.entries(btree, MemoryUtils.Nat);
                let entry = Utils.unwrap(entries.next(), "expected key");
                var prev = entry.0;

                for ((i, (key, val)) in Itertools.enumerate(entries)) {
                    if (prev > key) {
                        Debug.print("mismatch: " # debug_show (prev, key) # " at index " # debug_show i);
                        assert false;
                    };

                    let expected = Map.get(map, nhash, key);
                    if (expected != ?val) {
                        Debug.print("mismatch: " # debug_show (key, (expected, val)) # " at index " # debug_show (i + 1));
                        assert false;
                    };

                    if (?val != MemoryBTree.get(btree, MemoryUtils.Nat, key)) {
                        Debug.print("mismatch: " # debug_show (key, (expected, MemoryBTree.get(btree, MemoryUtils.Nat, key))) # " at index " # debug_show (i + 1));
                        assert false;
                    };

                    prev := key;
                };

                assert Methods.validate_memory(btree, MemoryUtils.Nat);

            },
        );

        test(
            "remove()",
            func() {

                // Debug.print("node keys: " # debug_show MemoryBTree.toNodeKeys(btree, MemoryUtils.Nat));
                // Debug.print("leaf nodes: " # debug_show MemoryBTree.toLeafNodes(btree, MemoryUtils.Nat));

                for ((key, i) in random.vals()) {
                    // Debug.print("removing " # debug_show key);
                    let val = MemoryBTree.remove(btree, MemoryUtils.Nat, key);
                    // Debug.print("(i, val): " # debug_show (i, val));
                    assert ?i == val;

                    assert MemoryBTree.size(btree) == random.size() - i - 1;
                    // Debug.print("node keys: " # debug_show MemoryBTree.toNodeKeys(btree, MemoryUtils.Nat));
                    // Debug.print("leaf nodes: " # debug_show Iter.toArray(MemoryBTree.leafNodes(btree, MemoryUtils.Nat)));
                };

                assert Methods.validate_memory(btree, MemoryUtils.Nat);

            },

        );

        test(
            "clear() after the btree has been re-populated",
            func() {
                MemoryBTree.clear(btree);
                assert MemoryBTree.size(btree) == 0;

                assert Methods.validate_memory(btree, MemoryUtils.Nat);

                MemoryBTree.clear(btree);
                assert MemoryBTree.size(btree) == 0;

                assert Methods.validate_memory(btree, MemoryUtils.Nat);
            },

        );

    },
);
