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
import BTreeUtils "../../src/MemoryBTree/BTreeUtils";
import Blobify "../../src/Blobify";
import MemoryCmp "../../src/MemoryCmp";
import Utils "../../src/Utils";
import Branch "../../src/MemoryBTree/modules/Branch";
import Leaf "../../src/MemoryBTree/modules/Leaf";
import Methods "../../src/MemoryBTree/modules/Methods";

type BTreeUtils<K, V> = MemoryBTree.BTreeUtils<K, V>;
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


let btree = MemoryBTree._new_with_options(?8, ?0, false);
let btree_utils = BTreeUtils.createUtils(BTreeUtils.BigEndian.Nat, BTreeUtils.BigEndian.Nat);
let candid_mem_utils = {
    key = candid_blobify;
    val =  candid_blobify;
    cmp = MemoryCmp.Nat
};

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
                    ignore MemoryBTree.insert(btree, btree_utils, k, i);
                    assert MemoryBTree.size(btree) == i + 1;

                    // Debug.print("keys " # debug_show MemoryBTree.toNodeKeys(btree, btree_utils));
                    // Debug.print("leafs " # debug_show MemoryBTree.toLeafNodes(btree, btree_utils));

                    let subtree_size = Branch.get_node_subtree_size(btree, btree.root);

                    // Debug.print("subtree_size " # debug_show subtree_size);
                    assert subtree_size == MemoryBTree.size(btree);

                    // Debug.print("(i, k, v) -> " # debug_show (i, k, MemoryBTree.get(btree, btree_utils, k)));
                    if (?i != MemoryBTree.get(btree, btree_utils, k)) {
                        Debug.print("mismatch: " # debug_show (k, (i, MemoryBTree.get(btree, btree_utils, k))) # " at index " # debug_show i);
                        assert false;
                    };

                };

                assert Methods.validate_memory(btree, btree_utils);

                // Debug.print("entries: " # debug_show Iter.toArray(MemoryBTree.entries(btree, btree_utils)));

                let entries = MemoryBTree.entries(btree, btree_utils);
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

                    if (?val != MemoryBTree.get(btree, btree_utils, key)) {
                        Debug.print("mismatch: " # debug_show (key, (expected, MemoryBTree.get(btree, btree_utils, key))) # " at index " # debug_show (i + 1));
                        assert false;
                    };

                    prev := key;
                };

                assert Methods.validate_memory(btree, btree_utils);
            },
        );

        test(
            "get()",
            func() {
                var i = 0;
                for ((key, val) in random.vals()) {
                    let got = MemoryBTree.get(btree, btree_utils, key);
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
                    let rank = MemoryBTree.getIndex(btree, btree_utils, key);
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
                    let received = MemoryBTree.getFromIndex(btree, btree_utils, i);

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
                    let received = MemoryBTree.getFloor(btree, btree_utils, key);

                    if (not (?expected == received)) {
                        Debug.print("mismatch at key:" # debug_show key);
                        Debug.print("expected != received: " # debug_show (expected, received));
                        assert false;
                    };

                    let prev = key - 1;

                    if (i > 0) {
                        let expected = sorted.get(i - 1);
                        let received = MemoryBTree.getFloor(btree, btree_utils, prev);

                        if (not (?(expected) == received)) {
                            Debug.print("mismatch at key:" # debug_show prev);
                            Debug.print("expected != received: " # debug_show (expected, received));
                            assert false;
                        };
                    } else {
                        assert MemoryBTree.getFloor(btree, btree_utils, prev) == null;
                    };

                    let next = key + 1;

                    do {
                        let expected = sorted.get(i);
                        let received = MemoryBTree.getFloor(btree, btree_utils, next);

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
                    let received = MemoryBTree.getCeiling<Nat, Nat>(btree, btree_utils, key);

                    if (not (?expected == received)) {
                        Debug.print("mismatch at key:" # debug_show key);
                        Debug.print("expected != received: " # debug_show (expected, received));
                        assert false;
                    };

                    let prev = key - 1;

                    do {
                        let expected = sorted.get(i);
                        let received = MemoryBTree.getCeiling<Nat, Nat>(btree, btree_utils, prev);

                        if (not (?expected == received)) {
                            Debug.print("mismatch at key:" # debug_show prev);
                            Debug.print("expected != received: " # debug_show (expected, received));
                            assert false;
                        };
                    };

                    let next = key + 1;

                    if (i + 1 < sorted.size()) {
                        let expected = sorted.get(i + 1);
                        let received = MemoryBTree.getCeiling<Nat, Nat>(btree, btree_utils, next);

                        if (not (?expected == received)) {
                            Debug.print("mismatch at key:" # debug_show next);
                            Debug.print("expected != received: " # debug_show (expected, received));
                            assert false;
                        };
                    } else {
                        assert MemoryBTree.getCeiling<Nat, Nat>(btree, btree_utils, next) == null;
                    };

                };
            },
        );
        test(
            "entries()",
            func() {
                var i = 0;
                for ((a, b) in Itertools.zip(MemoryBTree.entries(btree, btree_utils), sorted.vals())) {
                    if (a != b) {
                        Debug.print("mismatch: " # debug_show (a, b) # " at index " # debug_show i);
                        assert false;
                    };
                    i += 1;
                };

                assert i == sorted.size();

                assert Methods.validate_memory(btree, btree_utils);

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

                    for ((k, v) in MemoryBTree.scan<Nat, Nat>(btree, btree_utils, ?start_key, ?end_key)) {
                        let expected = sorted.get(index).0;

                        if (not (expected == k)) {
                            Debug.print("mismatch: " # debug_show (expected, k));
                            Debug.print("scan " # debug_show Iter.toArray(MemoryBTree.scan(btree, btree_utils, ?start_key, ?end_key)));

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
                            MemoryBTree.range(btree, btree_utils, i, j),
                            Itertools.fromArraySlice<(Nat, Nat)>(sorted_array, i, j + 1),
                            func(a : (Nat, Nat), b : (Nat, Nat)) : Bool = a == b,
                        )
                    ) {
                        Debug.print("mismatch: " # debug_show (i, j));
                        Debug.print("range " # debug_show Iter.toArray(MemoryBTree.range(btree, btree_utils, i, j)));
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

                    assert ?prev_val == MemoryBTree.insert<Nat, Nat>(btree, btree_utils, key, new_val);
                    assert ?new_val == MemoryBTree.get(btree, btree_utils, key);
                };

                assert Methods.validate_memory(btree, btree_utils);

            },
        );

        test(
            "remove() random",
            func() {

                // Debug.print("node keys: " # debug_show MemoryBTree.toNodeKeys(btree, btree_utils));
                // Debug.print("leaf nodes: " # debug_show MemoryBTree.toLeafNodes(btree, btree_utils));

                for ((key, i) in random.vals()) {
                    // Debug.print("removing " # debug_show key);
                    let val = MemoryBTree.remove(btree, btree_utils, key);
                    // Debug.print("(i, val): " # debug_show (i, val));
                    assert ?(i * 10) == val;

                    assert MemoryBTree.size(btree) == random.size() - i - 1;
                    // Debug.print("node keys: " # debug_show MemoryBTree.toNodeKeys(btree, btree_utils));
                    // Debug.print("leaf nodes: " # debug_show Iter.toArray(MemoryBTree.leafNodes(btree, btree_utils)));

                };

                assert Methods.validate_memory(btree, btree_utils);

            },

        );

        test(
            "clear()",
            func() {
                MemoryBTree.clear(btree);
                assert MemoryBTree.size(btree) == 0;

                assert Methods.validate_memory(btree, btree_utils);

                MemoryBTree.clear(btree);
                assert MemoryBTree.size(btree) == 0;

                assert Methods.validate_memory(btree, btree_utils);
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
                    ignore MemoryBTree.insert(btree, btree_utils, k, i);
                    assert MemoryBTree.size(btree) == i + 1;

                    // Debug.print("keys " # debug_show MemoryBTree.toNodeKeys(btree));
                    // Debug.print("leafs " # debug_show MemoryBTree.toLeafNodes(btree));

                    let subtree_size = Branch.get_node_subtree_size(btree, btree.root);

                    assert subtree_size == MemoryBTree.size(btree);

                    if (?i != MemoryBTree.get(btree, btree_utils, k)) {
                        Debug.print("mismatch: " # debug_show (k, (i, MemoryBTree.get(btree, btree_utils, k))) # " at index " # debug_show i);
                        assert false;
                    };
                };

                // Debug.print("entries: " # debug_show Iter.toArray(MemoryBTree.entries(btree, btree_utils)));

                let entries = MemoryBTree.entries(btree, btree_utils);
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

                    if (?val != MemoryBTree.get(btree, btree_utils, key)) {
                        Debug.print("mismatch: " # debug_show (key, (expected, MemoryBTree.get(btree, btree_utils, key))) # " at index " # debug_show (i + 1));
                        assert false;
                    };

                    prev := key;
                };

                assert Methods.validate_memory(btree, btree_utils);

            },
        );

        test(
            "remove()",
            func() {

                // Debug.print("node keys: " # debug_show MemoryBTree.toNodeKeys(btree, btree_utils));
                // Debug.print("leaf nodes: " # debug_show MemoryBTree.toLeafNodes(btree, btree_utils));

                for ((key, i) in random.vals()) {
                    // Debug.print("removing " # debug_show key);
                    let val = MemoryBTree.remove(btree, btree_utils, key);
                    // Debug.print("(i, val): " # debug_show (i, val));
                    assert ?i == val;

                    assert MemoryBTree.size(btree) == random.size() - i - 1;
                    // Debug.print("node keys: " # debug_show MemoryBTree.toNodeKeys(btree, btree_utils));
                    // Debug.print("leaf nodes: " # debug_show Iter.toArray(MemoryBTree.leafNodes(btree, btree_utils)));
                };

                assert Methods.validate_memory(btree, btree_utils);

            },

        );

        test(
            "clear() after the btree has been re-populated",
            func() {
                MemoryBTree.clear(btree);
                assert MemoryBTree.size(btree) == 0;

                assert Methods.validate_memory(btree, btree_utils);

                MemoryBTree.clear(btree);
                assert MemoryBTree.size(btree) == 0;

                assert Methods.validate_memory(btree, btree_utils);
            },

        );

    },
);
