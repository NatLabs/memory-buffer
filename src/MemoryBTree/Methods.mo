import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Order "mo:base/Order";

import MemoryRegion "mo:memory-region/MemoryRegion";
import LruCache "mo:lru-cache";
import BTree "mo:stableheapbtreemap/BTree";
import RevIter "mo:itertools/RevIter";
// import Branch "mo:augmented-btrees/BpTree/Branch";

import MemoryFns "./MemoryFns";
import Blobify "../Blobify";
import MemoryCmp "../MemoryCmp";
import ArrayMut "ArrayMut";
import T "Types";
import Leaf "Leaf";
import Branch "Branch";

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

    public func get_leaf_node<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>, key : K) : Leaf.Leaf {
        var curr = ?Branch.get_node(btree, btree.root);

        loop {
            switch (curr) {
                case (? #branch(node)) {
                    let int_index = switch (mem_utils.2) {
                        case (#cmp(cmp)) MemoryFns.binary_search<K, V>(btree, mem_utils, node.2, cmp, key, node.0 [Branch.AC.COUNT] - 1);
                        case (#blob_cmp(cmp)) {
                            let key_blob = mem_utils.0.to_blob(key);
                            MemoryFns.binary_search_blob_seq(btree.blobs, node.2, cmp, key_blob, node.0 [Branch.AC.COUNT] - 1);
                        };
                    };

                    let node_index = if (int_index >= 0) Int.abs(int_index) + 1 else Int.abs(int_index + 1);
                    let ?node_address = node.3 [node_index] else Debug.trap("get_leaf_node: accessed a null value");
                    curr := ?Branch.get_node(btree, node_address);
                };
                case (? #leaf(leaf_node)) return leaf_node;
                case (_) Debug.trap("get_leaf_node: accessed a null value");
            };
        };
    };

    public func get_min_leaf(btree : MemoryBTree) : Leaf {
        var curr = ?Branch.get_node(btree, btree.root);

        loop {
            switch (curr) {
                case (? #branch(branch)) {
                    let ?first_node_address = branch.3[0] else Debug.trap("get_min_leaf: accessed a null value");
                    curr := ?Branch.get_node(btree, first_node_address);
                };
                case (? #leaf(leaf_node)) {
                    return leaf_node;
                };
                case (_) Debug.trap("get_min_leaf_node: accessed a null value");
            };
        };
    };

    public func get_max_leaf(btree : MemoryBTree) : Leaf {
        var curr = ?Branch.get_node(btree, btree.root);

        loop {
            switch (curr) {
                case (? #branch(branch)) {
                    let last_index = branch.0[Branch.AC.COUNT] - 1;
                    let ?last_node_address = branch.3[last_index] else Debug.trap("get_max_leaf: accessed a null value");
                    curr := ?Branch.get_node(btree, last_node_address);
                };
                case (? #leaf(leaf_node)) {
                    return leaf_node;
                };
                case (_) Debug.trap("get_max_leaf: accessed a null value");
            };
        };
    };

    public func update_leaf_to_root(btree : MemoryBTree, leaf : Leaf, update : (MemoryBTree, Branch, Nat) -> ()) {
        var parent = leaf.1 [Leaf.AC.PARENT];
        var child_index = leaf.0 [Leaf.AC.INDEX];

        loop {
            switch (parent) {
                case (?branch_address) {
                    let branch = Branch.from_address(btree, branch_address);
                    update(btree, branch, child_index);
                    child_index := branch.0 [Branch.AC.INDEX];
                    parent := branch.1 [Branch.AC.PARENT];
                };

                case (_) return;
            };
        };
    };

    public func update_branch_to_root(btree : MemoryBTree, branch : Branch, update : (MemoryBTree, Branch, Nat) -> ()) {
        var parent = branch.1 [Branch.AC.PARENT];
        var child_index = branch.0 [Branch.AC.INDEX];

        loop {
            switch (parent) {
                case (?branch_address) {
                    let branch = Branch.from_address(btree, branch_address);
                    update(btree, branch, child_index);
                    child_index := branch.0 [Branch.AC.INDEX];
                    parent := branch.1 [Branch.AC.PARENT];
                };

                case (_) return;
            };
        };
    };

    // // Returns the leaf node and rank of the first element in the leaf node
    // public func get_leaf_node_and_index<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>, key : K) : (Leaf, Nat) {
    //     let root_node = Branch.get_node(btree, btree.root);

    //     let branch = switch (root_node) {
    //         case (#branch(node)) node;
    //         case (#leaf(leaf)) return (leaf, leaf.0[Leaf.AC.COUNT]);
    //     };

    //     var rank = branch.0[Branch.AC.SUBTREE_SIZE];

    //     func get_node(parent : Branch, key : K) : Leaf {
    //         var i = parent.0[Branch.AC.COUNT] - 1 : Nat;

    //         label get_node_loop while (i >= 1) {
    //             let child = parent.3[i];

    //             let ?search_key = parent.2[i - 1] else Debug.trap("get_leaf_node_and_index 1: accessed a null value");

    //             switch (child) {
    //                 case (? #branch(node)) {
    //                     if (cmp(key, search_key) == +1) {
    //                         return get_node(node, key);
    //                     };

    //                     rank -= node.0[Branch.AC.SUBTREE_SIZE];
    //                 };
    //                 case (? #leaf(node)) {
    //                     // subtract before comparison because we want the rank of the first element in the leaf node
    //                     rank -= node.0[Leaf.AC.COUNT];

    //                     if (cmp(key, search_key) == +1) {
    //                         return node;
    //                     };
    //                 };
    //                 case (_) Debug.trap("get_leaf_node_and_index 2: accessed a null value");
    //             };

    //             i -= 1;
    //         };

    //         switch (parent.3[0]) {
    //             case (?#branch(node)) {
    //                 return get_node(node, key);
    //             };
    //             case (? #leaf(node)) {
    //                 rank -= node.0[Leaf.AC.COUNT];
    //                 return node;
    //             };
    //             case (_) Debug.trap("get_leaf_node_and_index 3: accessed a null value");
    //         };
    //     };

    //     (get_node(branch, key), rank);
    // };

    public func new_iterator(
        btree : MemoryBTree,
        start_leaf : Leaf,
        start_index : Nat,
        end_leaf : Leaf,
        end_index : Nat // exclusive
    ) : RevIter<MemoryBlock> {

        var opt_start = ?start_leaf;
        var i = start_index;

        var opt_end = ?end_leaf;
        var j = end_index;

        func next() : ?MemoryBlock {
            let ?start = opt_start else return null;
            let ?end = opt_end else return null;

            if (start.0[Leaf.AC.ADDRESS] == end.0[Leaf.AC.ADDRESS] and i >= j) {
                opt_start := null;
                return null;
            };

            if (i >= start.0[Leaf.AC.COUNT]) {
                opt_start := switch(start.1[Leaf.AC.NEXT]){
                    case (null) null;
                    case (?next_address) ?Leaf.from_address(btree, next_address);
                };
                i := 0;
                return next();
            };

            let mem_block = start.2[i];
            i += 1;
            return mem_block;
        };

        func nextFromEnd() : ?MemoryBlock {
            let ?start = opt_start else return null;
            let ?end = opt_end else return null;

            if (start.0[Leaf.AC.ADDRESS] == end.0[Leaf.AC.ADDRESS] and i >= j) {
                opt_end := null;
                return null;
            };

            if (j == 0) {
                opt_end := switch(start.1[Leaf.AC.PREV]){
                    case (null) null;
                    case (?prev_address) ?Leaf.from_address(btree, prev_address);
                };

                switch (opt_end) {
                    case (?leaf) j := leaf.0[Leaf.AC.COUNT];
                    case (_) { return null };
                };

                return nextFromEnd();
            };

            let mem_block = end.2[j - 1];
            j -= 1;

            return mem_block;
        };

        RevIter.new(next, nextFromEnd);
    };

    public func entries<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>) : RevIter<(K, V)> {
        let min_leaf = get_min_leaf(btree);
        let max_leaf = get_max_leaf(btree);
        let mem_blocks_iter = new_iterator(btree, min_leaf, 0, max_leaf, max_leaf.0[Leaf.AC.COUNT]);

        RevIter.map<MemoryBlock, (K, V)>(
            mem_blocks_iter,
            func((kv_offset, key_size, value_size): MemoryBlock) : (K, V) {
                let key_blob = MemoryRegion.loadBlob(btree.blobs, kv_offset, key_size);
                let value_blob = MemoryRegion.loadBlob(btree.blobs, kv_offset + key_size, value_size);

                let key = mem_utils.0.from_blob(key_blob);
                let value = mem_utils.1.from_blob(value_blob);
                (key, value);
            }
        );
    };

    public func keys<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>) : RevIter<(K)> {
        let min_leaf = get_min_leaf(btree);
        let max_leaf = get_max_leaf(btree);
        let mem_blocks_iter = new_iterator(btree, min_leaf, 0, max_leaf, max_leaf.0[Leaf.AC.COUNT]);

        RevIter.map<MemoryBlock, (K)>(
            mem_blocks_iter,
            func((kv_offset, key_size, value_size): MemoryBlock) : (K) {
                let key_blob = MemoryRegion.loadBlob(btree.blobs, kv_offset, key_size);

                let key = mem_utils.0.from_blob(key_blob);
                key;
            }
        );
    };

    public func vals<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>) : RevIter<(V)> {
        let min_leaf = get_min_leaf(btree);
        let max_leaf = get_max_leaf(btree);
        let mem_blocks_iter = new_iterator(btree, min_leaf, 0, max_leaf, max_leaf.0[Leaf.AC.COUNT]);

        RevIter.map<MemoryBlock, V>(
            mem_blocks_iter,
            func((kv_offset, key_size, value_size): MemoryBlock) : V {
                let value_blob = MemoryRegion.loadBlob(btree.blobs, kv_offset + key_size, value_size);
                let value = mem_utils.1.from_blob(value_blob);
                
                value;
            }
        );
    };
    
}