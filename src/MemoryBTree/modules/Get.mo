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
import MemoryBlock "MemoryBlock";

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

    public func get_leaf_address<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>, key : K, _opt_key_blob: ?Blob) : Nat {
        var curr_address = btree.root;
        var opt_key_blob : ?Blob = _opt_key_blob;

        loop {
            switch (Branch.get_node_type(btree, curr_address)) {
                case (#leaf) {
                    Leaf.add_to_cache(btree, curr_address);
                    return curr_address
                };
                case (#branch) {
                    // load breanch from stable memory
                    // and add it to the cache
                    Branch.add_to_cache(btree, curr_address);

                    let count = Branch.get_count(btree, curr_address);
                    
                    let int_index = switch (mem_utils.2) {
                        case (#cmp(cmp)) Branch.binary_search<K, V>(btree, mem_utils, curr_address, cmp, key, count - 1);
                        case (#blob_cmp(cmp)) {

                            let key_blob = switch(opt_key_blob){
                                case (null) {
                                    let key_blob = mem_utils.0.to_blob(key);
                                    opt_key_blob := ?key_blob;
                                    key_blob
                                };
                                case (?key_blob) key_blob;
                            };

                            Branch.binary_search_blob_seq(btree, curr_address, cmp, key_blob, count - 1);
                        };
                    };

                    let child_index = if (int_index >= 0) Int.abs(int_index) + 1 else Int.abs(int_index + 1);
                    let ?child_address = Branch.get_child(btree, curr_address, child_index) else Debug.trap("get_leaf_node: accessed a null value");
                    curr_address := child_address;
                };
            };
        };
    };

    public func get_min_leaf_address(btree : MemoryBTree) : Nat {
        var curr = btree.root;

        loop {
            switch (Branch.get_node_type(btree, curr)) {
                case (#branch) {
                    let ?first_child = Branch.get_child(btree, curr, 0) else Debug.trap("get_min_leaf: accessed a null value");
                    curr := first_child;
                };
                case (#leaf) return curr;
            };
        };
    };

    public func get_max_leaf_address(btree : MemoryBTree) : Nat {
        var curr = btree.root;

        loop {
            switch (Branch.get_node_type(btree, curr)) {
                case (#branch) {
                    let count = Branch.get_count(btree, curr);
                    let ?first_child = Branch.get_child(btree, curr, count - 1) else Debug.trap("get_min_leaf: accessed a null value");
                    curr := first_child;
                };
                case (#leaf) return curr;
            };
        };
    };

    public func update_leaf_to_root(btree : MemoryBTree, leaf_address : Nat, update : (MemoryBTree, Nat, Nat) -> ()) {
        var parent = Leaf.get_parent(btree, leaf_address);
        var child_index = Leaf.get_index(btree, leaf_address);

        loop {
            switch (parent) {
                case (?branch_address) {
                    update(btree, branch_address, child_index);
                    child_index := Branch.get_index(btree, branch_address);
                    parent := Branch.get_parent(btree, branch_address);
                };

                case (_) return;
            };
        };
    };

    public func update_branch_to_root(btree : MemoryBTree, branch_address : Nat, update : (MemoryBTree, Nat, Nat) -> ()) {
        var parent = Branch.get_parent(btree, branch_address);
        var child_index = Branch.get_index(btree, branch_address);

        loop {
            switch (parent) {
                case (?branch_address) {
                    update(btree, branch_address, child_index);
                    child_index := Branch.get_index(btree, branch_address);
                    parent := Branch.get_parent(btree, branch_address);
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
    
}