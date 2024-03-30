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

module Branch {

    type Address = Nat;
    type MemoryRegion = MemoryRegion.MemoryRegion;
    type LruCache<K, V> = LruCache.LruCache<K, V>;
    type Blobify<A> = Blobify.Blobify<A>;
    type RevIter<A> = RevIter.RevIter<A>;
    type MemoryBTree = T.MemoryBTree;
    type Node = T.Node;

    public type Branch = T.Branch;

    public type MemoryCmp<A> = MemoryCmp.MemoryCmp<A>;

    let { nhash } = LruCache;

    // access constants
    public let AC = {
        ADDRESS = 0;
        INDEX = 1;
        COUNT = 2;
        SUBTREE_SIZE = 3;

        PARENT = 0;
    };

    // memory constants
    public let MC = {
        ADDRESS_SIZE = 8;

        FLAG_SIZE = 1;
        PARENT_START = 1;
        PARENT_SIZE = 8;

        INDEX_START = 9;
        INDEX_SIZE = 2;

        SUBTREE_COUNT_START = 11;
        SUBTREE_COUNT_SIZE = 8;

        COUNT_START = 19;
        COUNT_SIZE = 2;

        KEYS_START = 21;
        KEY_SIZE = 2;

        NULL_ADDRESS = 0x00;

    };

    public func get_memory_size(btree : MemoryBTree) : Nat {
        let bytes_per_node = Branch.MC.FLAG_SIZE // flags
        + Branch.MC.PARENT_SIZE // parent address
        + Branch.MC.INDEX_SIZE // Node's position in parent node
        + Branch.MC.SUBTREE_COUNT_SIZE // number of elements in the node
        + Branch.MC.COUNT_SIZE // number of elements in the node
        // key pointers
        + (
            (
                Branch.MC.ADDRESS_SIZE // address of memory block
                + Branch.MC.KEY_SIZE // key size
            ) * (btree.order - 1)
        )
        // children nodes
        + (Branch.MC.ADDRESS_SIZE * btree.order);

        bytes_per_node;
    };

    public func new(btree : MemoryBTree) : Branch {
        let bytes_per_node = Branch.get_memory_size(btree);

        let branch_address = MemoryRegion.allocate(btree.metadata, bytes_per_node);

        let branch : Branch = (
            [var branch_address, 0, 0, 0],
            [var null],
            Array.init<?(Nat, Nat)>(btree.order - 1, null),
            Array.init<?Nat>(btree.order, null),
        );

        let flag : Nat8 = 0;
        MemoryRegion.storeNat8(btree.metadata, branch_address, flag); // flags
        // skip parent
        MemoryRegion.storeNat16(btree.metadata, branch_address + MC.INDEX_START, 0); // Node's position in parent node
        MemoryRegion.storeNat64(btree.metadata, branch_address + MC.SUBTREE_COUNT_START, 0); // number of elements in the node
        MemoryRegion.storeNat16(btree.metadata, branch_address + MC.COUNT_START, 0); // number of elements in the node

        LruCache.put(btree.nodes_cache, nhash, branch.0 [AC.ADDRESS], #branch(branch));

        branch;
    };

    public func from_memory(btree : MemoryBTree, address : Address) : Branch {
        let flags = MemoryRegion.loadNat8(btree.metadata, address);

        let is_leaf = flags & 0x80 == 0x80;
        let is_root = flags & 0x40 == 0x40;

        assert not is_leaf;

        let index = MemoryRegion.loadNat16(btree.metadata, address + MC.INDEX_START) |> Nat16.toNat(_);
        let count = MemoryRegion.loadNat16(btree.metadata, address + MC.COUNT_START) |> Nat16.toNat(_);
        let subtree_size = MemoryRegion.loadNat64(btree.metadata, address + MC.SUBTREE_COUNT_START) |> Nat64.toNat(_);

        let branch : Branch = (
            [var address, index, count, subtree_size],
            [var null],
            Array.init<?(Nat, Nat)>(btree.order - 1, null),
            Array.init<?Nat>(btree.order, null),
        );

        branch.1 [AC.PARENT] := if is_root { null } else { 
            MemoryRegion.loadNat64(btree.metadata, address + MC.PARENT_START) 
            |> ?Nat64.toNat(_);
        };

        for (i in Iter.range(0, btree.order - 2)) {
            let key_offset = address + MC.KEYS_START + (i * (MC.KEY_SIZE + MC.ADDRESS_SIZE));

            let key = (
                MemoryRegion.loadNat64(btree.metadata, key_offset) |> Nat64.toNat(_),
                MemoryRegion.loadNat16(btree.metadata, key_offset + MC.ADDRESS_SIZE) |> Nat16.toNat(_),
            );

            branch.2 [i] := ?key;
        };

        for (i in Iter.range(0, btree.order - 1)) {
            let child_offset = address + CHILDREN_START(btree) + (i * MC.ADDRESS_SIZE);

            let child_address = MemoryRegion.loadNat64(btree.metadata, child_offset) |> Nat64.toNat(_);
            branch.3 [i] := ?child_address;
        };

        branch;
    };

    public func from_address(btree : MemoryBTree, address : Address) : Branch {
        switch (LruCache.get(btree.nodes_cache, nhash, address)){
            case (?#branch(branch)) return branch;
            case (null) {};
            case (?#leaf(_)) Debug.trap("Branch.from_address(): Expected a branch, got a leaf");
        };

        let branch = Branch.from_memory(btree, address);
        LruCache.put(btree.nodes_cache, nhash, address, #branch(branch));
        branch;
    };

    public func update_count(btree : MemoryBTree, branch : Branch, new_count : Nat) {
        MemoryRegion.storeNat16(btree.metadata, branch.0 [AC.ADDRESS] + MC.COUNT_START, Nat16.fromNat(new_count));
        branch.0 [AC.COUNT] := new_count;
    };

    public func update_index(btree : MemoryBTree, branch : Branch, new_index : Nat) {
        MemoryRegion.storeNat16(btree.metadata, branch.0 [AC.ADDRESS] + MC.INDEX_START, Nat16.fromNat(new_index));
        branch.0 [AC.INDEX] := new_index;
    };

    public func update_subtree_size(btree : MemoryBTree, branch : Branch, new_size : Nat) {
        MemoryRegion.storeNat32(btree.metadata, branch.0 [AC.ADDRESS] + MC.SUBTREE_COUNT_START, Nat32.fromNat(new_size));
        branch.0 [AC.SUBTREE_SIZE] := new_size;
    };

    public func update_parent(btree : MemoryBTree, branch : Branch, parent : ?Nat) {
        switch (parent) {
            case (null) {
                branch.1 [AC.PARENT] := null;
                MemoryRegion.storeNat64(btree.metadata, branch.0[AC.ADDRESS] + MC.PARENT_START, Nat64.fromNat(MC.NULL_ADDRESS));
            };
            case (?_parent) {
                MemoryRegion.storeNat64(btree.metadata, branch.0 [AC.ADDRESS] + MC.PARENT_START, Nat64.fromNat(_parent));
                branch.1 [AC.PARENT] := parent;
            };
        };
    };

    public func put_key(btree : MemoryBTree, branch : Branch, i : Nat, key : (Nat, Nat)) {
        assert i < btree.order - 1;

        branch.2 [i] := ?key;
        let offset = branch.0 [AC.ADDRESS] + MC.KEYS_START + (i * (MC.KEY_SIZE + MC.ADDRESS_SIZE));
        MemoryRegion.storeNat64(btree.metadata, offset, Nat64.fromNat(key.0));
        MemoryRegion.storeNat16(btree.metadata, offset + MC.ADDRESS_SIZE, Nat16.fromNat(key.1));
    };

    public func CHILDREN_START(btree : MemoryBTree) : Nat {
        MC.KEYS_START + ((btree.order - 1) * MC.KEY_SIZE);
    };

    public func add_child(btree : MemoryBTree, branch : Branch, child_node : Node) {
        let count = branch.0 [AC.COUNT];
        assert count < btree.order;

        Branch.put_child(btree, branch, count, child_node);
        Branch.update_count(btree, branch, count + 1);
    };

    public func put_child(btree : MemoryBTree, branch : Branch, i : Nat, node : Node) {
        assert i < btree.order;

        let child_address = switch(node){
            case (#leaf(child))  {
                Leaf.update_parent(btree, child, ?branch.0 [AC.ADDRESS]);
                Leaf.update_index(btree, child, i);

                Branch.update_subtree_size(btree, branch, branch.0[AC.SUBTREE_SIZE] + child.0[Leaf.AC.COUNT]);
                child.0 [AC.ADDRESS];
            };
            case (#branch(child)) {
                Branch.update_parent(btree, child, ?branch.0 [AC.ADDRESS]);
                Branch.update_index(btree, child, i);

                Branch.update_subtree_size(btree, branch, branch.0[AC.SUBTREE_SIZE] + child.0[AC.SUBTREE_SIZE]);
                child.0 [AC.ADDRESS];
            };
        };

        branch.3 [i] := ?(child_address);

        let offset = branch.0 [AC.ADDRESS] + CHILDREN_START(btree) + (i * MC.ADDRESS_SIZE);
        MemoryRegion.storeNat64(btree.metadata, offset, Nat64.fromNat(child_address));
    };

    public func get_node(btree : MemoryBTree, node_address : Nat) : Node {
        let is_leaf = switch (LruCache.get(btree.nodes_cache, nhash, node_address)) {
            case (?node) return node;
            case (_) {
                let flag = MemoryRegion.loadNat8(btree.metadata, node_address);
                let is_leaf = (flag & 0x80) == 0x80;
            };
        };

        let node = if (is_leaf) {
            #leaf(Leaf.from_memory(btree, node_address));
        } else {
            #branch(Branch.from_memory(btree, node_address));
        };

        LruCache.put(btree.nodes_cache, nhash, node_address, node);
        node;
    };

    public func update_median_key(btree: MemoryBTree, parent_branch: Branch, index: Nat, new_key: (Nat, Nat)){
        var curr = parent_branch;
        var i = index;

        while (i == 0){
            i:= curr.0[AC.INDEX];
            let ?parent_address = curr.1[AC.PARENT] else return; // occurs when key is the first key in the tree
            curr := Branch.from_address(btree, parent_address);
        };

        Branch.put_key(btree, curr, i - 1, new_key);
    };

    public func insert(btree : MemoryBTree, branch : Branch, i : Nat, key : (Nat, Nat), child : Node) {

        var j = branch.0 [AC.COUNT];
    //  Debug.print("branch = " # debug_show branch);
    //  Debug.print("i = " # debug_show i);
    //  Debug.print("j = " # debug_show j);
        assert j < btree.order;
        assert i <= branch.0 [AC.COUNT];

        while (j >= i) {
        //  Debug.print("(i, j) " # debug_show (i, j));
            if (j == i) {
                branch.2 [j - 1] := ?key;
                let #leaf(node) or #branch(node) = child;
                branch.3 [j] := ?node.0 [AC.ADDRESS];
            } else {
                branch.2 [j - 1] := branch.2 [j - 2];
                branch.3 [j] := branch.3 [j - 1];
            };

            let ?child_address = branch.3 [j] else Debug.trap("Branch.insert(): child address is null");
            let child_node = Branch.get_node(btree, child_address);

            switch (child_node) {
                case ((#branch(node))) {
                    Branch.update_index(btree, node, j);
                };
                case (#leaf(node)){
                    Leaf.update_index(btree, node, j);
                };
            };

            j -= 1;
        };

        if (i == 0) {
            update_median_key(btree, branch, i, key);
        } else {
            let key_offset = branch.0 [AC.ADDRESS] + MC.KEYS_START + ((i - 1) * (MC.KEY_SIZE + MC.ADDRESS_SIZE));
            MemoryRegion.storeNat64(btree.metadata, key_offset, Nat64.fromNat(key.0));
            MemoryRegion.storeNat16(btree.metadata, key_offset + MC.ADDRESS_SIZE, Nat16.fromNat(key.1));
        };

        let child_offset = branch.0 [AC.ADDRESS] + CHILDREN_START(btree) + (i * MC.ADDRESS_SIZE);
        let #leaf(child_node) or #branch(child_node) = child;
        MemoryRegion.storeNat64(btree.metadata, child_offset, Nat64.fromNat(child_node.0 [AC.ADDRESS]));

        Branch.update_count(btree, branch, branch.0[AC.COUNT] + 1);
    //  Debug.print("branch after insert = " # debug_show branch);
        
    };

    public func split(btree: MemoryBTree, branch : Branch, child_index : Nat, first_child_key : (Nat, Nat), child : Node) : Branch {
        let arr_len = branch.0[AC.COUNT];
        let median = (arr_len / 2) + 1;

        let is_elem_added_to_right = child_index >= median;

        var median_key = ?first_child_key;

        var offset = if (is_elem_added_to_right) 0 else 1;
        var already_inserted = false;

        let right_cnt = arr_len + 1 - median : Nat;
        let right_branch = Branch.new(btree);
        
        var i = 0;
        
        while (i < right_cnt) {
            let j = i + median - offset : Nat;

            let ?child_node = if (j >= median and j == child_index and not already_inserted) {
                offset += 1;
                already_inserted := true;
                if (i > 0) Branch.put_key(btree, right_branch, i - 1, first_child_key);
                ?child;
            } else {
                if (i == 0) {
                    median_key := branch.2[j - 1];
                } else {
                    let ?shifted_key = branch.2[j - 1] else Debug.trap("Branch.split: accessed a null value");
                    Branch.put_key(btree, right_branch, i - 1, shifted_key);
                };

                branch.2[j - 1] := null;
                let ?child_address = ArrayMut.extract(branch.3, j) else Debug.trap("Branch.split: accessed a null value");
                
                // decrement the left branch count
                branch.0[AC.COUNT] -= 1;

                ?Branch.get_node(btree, child_address);
            } else Debug.trap("Branch.split: accessed a null value");

            Branch.add_child(btree, right_branch, child_node);
            i += 1;
        };

        // remove the elements moved to the right branch from the subtree size of the left branch
        Branch.update_subtree_size(btree, branch, branch.0[AC.SUBTREE_SIZE] - right_branch.0[AC.SUBTREE_SIZE]);

        if (not is_elem_added_to_right) {
            Branch.insert(btree, branch, child_index, first_child_key, child);
        };

        Branch.update_count(btree, branch, median);

        Branch.update_index(btree, right_branch, branch.0[AC.INDEX] + 1);

        Branch.update_count(btree, right_branch, right_cnt);
        Branch.update_parent(btree, right_branch, branch.1[AC.PARENT]);

        // store the first key of the right node at the end of the keys in left node
        // no need to delete as the value will get overwritten because it exceeds the count position
        right_branch.2[right_branch.2.size() - 1] := median_key;

        right_branch;
    };
};
