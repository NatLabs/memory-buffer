// @testmode wasi
import { test; suite } "mo:test";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Nat32 "mo:base/Nat32";
import Nat "mo:base/Nat";

import LruCache "mo:lru-cache";
import Fuzz "mo:fuzz";
import Itertools "mo:itertools/Iter";
import Map "mo:map/Map";

import MemoryBTree "../../src/MemoryBTree/Base";
import MemoryUtils "../../src/MemoryBTree/MemoryUtils";
import VersionedMemoryBuffer "../../src/VersionedMemoryBuffer";
import Migrations "../../src/Migrations";
import Blobify "../../src/Blobify";
import MemoryCmp "../../src/MemoryCmp";
import Utils "../../src/Utils";
import Branch "../../src/MemoryBTree/Branch";
import Leaf "../../src/MemoryBTree/Leaf";

type MemoryUtils<K, V> = MemoryBTree.MemoryUtils<K, V>;
type Buffer<A> = Buffer.Buffer<A>;
type Iter<A> = Iter.Iter<A>;

let { nhash } = Map;
let fuzz = Fuzz.fromSeed(0xdeadbeef);

let limit = 10_000;

let nat_gen_iter : Iter<Nat> = {
    next = func() : ?Nat = ?fuzz.nat.randomRange(1, limit * 10);
};
let unique_iter = Itertools.unique<Nat>(nat_gen_iter, Nat32.fromNat, Nat.equal);
let random = Itertools.toBuffer<Nat>(Itertools.take(unique_iter, limit));

suite(
    "MemoryBTree",
    func() {
        test(
            "new()",
            func() {
                let btree = MemoryBTree.new(?4);
                assert MemoryBTree.size(btree) == 0;

                ignore MemoryBTree.insert(btree, MemoryUtils.Nat, 1, 1);
                ignore MemoryBTree.insert(btree, MemoryUtils.Nat, 2, 2);
                ignore MemoryBTree.insert(btree, MemoryUtils.Nat, 0, 0);
                ignore MemoryBTree.insert(btree, MemoryUtils.Nat, 3, 3);

                assert MemoryBTree.size(btree) == 4;

                ignore MemoryBTree.insert(btree, MemoryUtils.Nat, 4, 4);
                ignore MemoryBTree.insert(btree, MemoryUtils.Nat, 6, 6);
                ignore MemoryBTree.insert(btree, MemoryUtils.Nat, 5, 5);
                ignore MemoryBTree.insert(btree, MemoryUtils.Nat, 7, 7);

                Debug.print("btree: " # debug_show Iter.toArray(LruCache.entries(btree.nodes_cache)));

                assert MemoryBTree.size(btree) == 8;

            },
        );
        test(
            "insert random",
            func() {
                let map = Map.new<Nat, Nat>();
                let btree = MemoryBTree.new(?4);
                assert btree.order == 4;

                // Debug.print("random size " # debug_show random.size());
                label for_loop for ((i, k) in Itertools.enumerate(random.vals())) {
                    Debug.print("inserting " # debug_show k # " at index " # debug_show i);

                    ignore Map.put(map, nhash, k, i);
                    ignore MemoryBTree.insert(btree, MemoryUtils.Nat, k, i);
                    assert MemoryBTree.size(btree) == i + 1;

                    // Debug.print("keys " # debug_show MemoryBTree.toNodeKeys(btree));
                    // Debug.print("leafs " # debug_show MemoryBTree.toLeafNodes(btree));

                    let subtree_size = switch (Branch.get_node(btree, btree.root)) {
                        case (#branch(node)) { node.0 [Branch.AC.SUBTREE_SIZE] };
                        case (#leaf(node)) { node.0 [Leaf.AC.COUNT] };
                    };

                    Debug.print("subtree_size " # debug_show subtree_size);
                    assert subtree_size == MemoryBTree.size(btree);
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

                    prev := key;
                };
            },
        );

    },
);
