import Debug "mo:base/Debug";
import Nat "mo:base/Nat";

import Blob "mo:base/Blob";

import MemoryRegion "mo:memory-region/MemoryRegion";
import LruCache "mo:lru-cache";
import RevIter "mo:itertools/RevIter";
// import Branch "mo:augmented-btrees/BpTree/Branch";

import Blobify "../../Blobify";
import MemoryCmp "../../MemoryCmp";
import T "../Types";
import Leaf "../Leaf";
import Branch "../Branch";
import MemoryBlock "../MemoryBlock";

module {
    public type Leaf = T.Leaf;
    type MemoryBTree = T.MemoryBTree;
    type MemoryBlock = T.MemoryBlock;

    type Address = Nat;
    type MemoryRegion = MemoryRegion.MemoryRegion;
    type LruCache<K, V> = LruCache.LruCache<K, V>;
    type Blobify<A> = Blobify.Blobify<A>;
    type RevIter<A> = RevIter.RevIter<A>;
    type Node = T.Node;
    public type MemoryUtils<K, V> = T.MemoryUtils<K, V>;

    public type Branch = T.Branch;

    public type MemoryCmp<A> = MemoryCmp.MemoryCmp<A>;

    public func new_blobs_iterator(
        btree : MemoryBTree,
        start_leaf : Nat,
        start_index : Nat,
        end_leaf : Nat,
        end_index : Nat // exclusive
    ) : RevIter<(Blob, Blob)> {

        var start = start_leaf;
        var i = start_index;
        var start_count = Leaf.get_count(btree, start_leaf);

        var end = end_leaf;
        var j = end_index;

        var terminate = false;

        func next() : ?(Blob, Blob) {
            if (terminate) return null;

            if (start == end and i >= j) {
                return null;
            };

            if (i >= start_count) {
                switch(Leaf.get_next(btree, start)){
                    case (null) {
                        terminate := true;
                    };
                    case (?next_address) {
                        start := next_address;
                        start_count := Leaf.get_count(btree, next_address);
                    };
                };

                i := 0;
                return next();
            };

            let opt_kv = Leaf.get_kv_blobs(btree, start, i);

            i += 1;
            return opt_kv;
        };

        func nextFromEnd() : ?(Blob, Blob) {
            if (terminate) return null;

            if (start == end and i >= j) return null;

            if (j == 0) {
                switch(Leaf.get_prev(btree, end)){
                    case (null) terminate := true;
                    case (?prev_address) {
                        end := prev_address;
                        j := Leaf.get_count(btree, prev_address);
                    };
                };

                return nextFromEnd();
            };

            let opt_kv = Leaf.get_kv_blobs(btree, end, j - 1);

            j -= 1;

            return opt_kv;
        };

        RevIter.new(next, nextFromEnd);
    };

    public func blocks(btree : MemoryBTree) : RevIter<(Blob, Blob)> {
        let min_leaf = get_min_leaf_address(btree);
        let max_leaf = get_max_leaf_address(btree);
        let max_leaf_count = Leaf.get_count(btree, max_leaf);

        new_blobs_iterator(btree, min_leaf, 0, max_leaf, max_leaf_count);
    };

    public func entries<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>) : RevIter<(K, V)> {
        RevIter.map<(Blob, Blob), (K, V)>(
            blocks(btree),
            func((key_blob, val_blob): (Blob, Blob)) : (K, V) {
                let key = mem_utils.0.from_blob(key_blob);
                let value = mem_utils.1.from_blob(val_blob);
                (key, value);
            }
        );
    };

    public func keys<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>) : RevIter<(K)> {
        RevIter.map<(Blob, Blob), (K)>(
            blocks(btree),
            func((key_blob, _): (Blob, Blob)) : (K) {
                let key = mem_utils.0.from_blob(key_blob);
                key;
            }
        );
    };

    public func vals<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>) : RevIter<(V)> {
        RevIter.map<(Blob, Blob), V>(
            blocks(btree),
            func((_, val_blob): (Blob, Blob)) : V {
                let value = mem_utils.1.from_blob(val_blob);
                value;
            }
        );
    };
    
}