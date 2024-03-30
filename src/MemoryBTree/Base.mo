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
import Leaf "Leaf";
import Branch "Branch";
import T "Types";
import ArrayMut "ArrayMut";
import Methods "Methods";
import MemoryBlock "MemoryBlock";

module {
    type Address = Nat;
    type MemoryRegion = MemoryRegion.MemoryRegion;
    type LruCache<K, V> = LruCache.LruCache<K, V>;
    type Blobify<A> = Blobify.Blobify<A>;
    type RevIter<A> = RevIter.RevIter<A>;

    public type MemoryCmp<A> = MemoryCmp.MemoryCmp<A>;

    public type MemoryBTree = T.MemoryBTree;
    public type Node = T.Node;
    public type Leaf = T.Leaf;
    public type Branch = T.Branch;
    public type MemoryBlock = T.MemoryBlock;
    public type MemoryUtils<K, V> = T.MemoryUtils<K, V>;

    let { nhash } = LruCache;

    let CACHE_LIMIT = 100_000;

    public func _new_with_options(order : ?Nat, is_set : Bool) : MemoryBTree {
        let btree_map : MemoryBTree = {
            is_set;
            order = Option.get(order, 32);
            var count = 0;
            var root = 0;
            metadata = MemoryRegion.new();
            blobs = MemoryRegion.new();
            nodes_cache = LruCache.new(CACHE_LIMIT);
        };

        init_region_header(btree_map);

        let leaf = Leaf.new(btree_map);
        Leaf.set_is_root(btree_map, leaf, true);

        let node = #leaf(leaf);
        update_root(btree_map, node);

        return btree_map;
    };

    public func new_set(order : ?Nat) : MemoryBTree {
        _new_with_options(order, true);
    };

    public func new(order : ?Nat) : MemoryBTree {
        _new_with_options(order, false);
    };

    public let REGION_HEADER_SIZE = 64;

    public let POINTER_SIZE = 12;
    public let LAYOUT_VERSION = 0;

    public let Layout = [
        {
            MAGIC_NUMBER_ADDRESS = 0;
            LAYOUT_VERSION_ADDRESS = 3;
            REGION_ID_ADDRESS = 4;
            ORDER_ADDRESS = 8;
            ROOT_ADDRESS = 16;
            COUNT_ADDRESS = 24;
            POINTERS_START = 64;
            BLOB_START = 64;
        },
    ];

    let MC = {
        MAGIC_NUMBER_ADDRESS = 00;
        LAYOUT_VERSION_ADDRESS = 3;
        REGION_ID_ADDRESS = 4;
        ORDER_ADDRESS = 8;
        ROOT_ADDRESS = 16;
        COUNT_ADDRESS = 24;
        NODES_START = 64;
        BLOB_START = 64;
    };

    func init_region_header(btree : MemoryBTree) {
        assert MemoryRegion.size(btree.blobs) == 0;
        assert MemoryRegion.size(btree.metadata) == 0;

        // Each Region has a 64 byte header
        ignore MemoryRegion.allocate(btree.blobs, REGION_HEADER_SIZE); // Reserved Space for the Region Header
        MemoryRegion.storeBlob(btree.blobs, MC.MAGIC_NUMBER_ADDRESS, "BLB"); // MAGIC NUMBER (BLB -> Blob Region) 3 bytes
        MemoryRegion.storeNat8(btree.blobs, MC.LAYOUT_VERSION_ADDRESS, Nat8.fromNat(LAYOUT_VERSION)); // |1 byte | Layout Version (1)
        MemoryRegion.storeNat32(btree.blobs, MC.REGION_ID_ADDRESS, Nat32.fromNat(MemoryRegion.id(btree.metadata))); // store the pointers region id in the blob region
        assert MemoryRegion.size(btree.blobs) == REGION_HEADER_SIZE;

        // | 64 byte header | -> 3 bytes + 1 byte + 8 bytes + 52 bytes
        ignore MemoryRegion.allocate(btree.metadata, REGION_HEADER_SIZE); // Reserved Space for the Region Header
        MemoryRegion.storeBlob(btree.metadata, MC.MAGIC_NUMBER_ADDRESS, "BTM"); // |3 bytes| MAGIC NUMBER (BTM -> BTree Map Region)
        MemoryRegion.storeNat8(btree.metadata, MC.LAYOUT_VERSION_ADDRESS, Nat8.fromNat(LAYOUT_VERSION)); // |1 byte | Layout Version (1)
        MemoryRegion.storeNat32(btree.metadata, MC.REGION_ID_ADDRESS, Nat32.fromNat(MemoryRegion.id(btree.blobs))); // store the blobs region id in the pointers region
        MemoryRegion.storeNat16(btree.metadata, MC.ORDER_ADDRESS, Nat16.fromNat(btree.order)); // |2 bytes| Order -> Number of elements allowed in each node
        MemoryRegion.storeNat64(btree.metadata, MC.ROOT_ADDRESS, 0); // |8 bytes| Root -> Address of the root node
        MemoryRegion.storeNat64(btree.metadata, MC.COUNT_ADDRESS, 0); // |8 bytes| Count -> Number of elements in the buffer
        assert MemoryRegion.size(btree.metadata) == REGION_HEADER_SIZE;
    };

    public func size(btree : MemoryBTree) : Nat {
        btree.count;
    };

    func update_root(btree : MemoryBTree, new_root : Node) {
        btree.root := switch (new_root) {
            case (#leaf(leaf)) leaf.0 [Leaf.AC.ADDRESS];
            case (#branch(branch)) branch.0 [Branch.AC.ADDRESS];
        };

        MemoryRegion.storeNat64(btree.metadata, MC.ROOT_ADDRESS, Nat64.fromNat(btree.root));
    };

    func update_count(btree : MemoryBTree, new_count : Nat) {
        btree.count := new_count;
        MemoryRegion.storeNat64(btree.metadata, MC.COUNT_ADDRESS, Nat64.fromNat(new_count));
    };

    func inc_subtree_size_upstream(btree: MemoryBTree, branch: Branch, _child_index: Nat) {
        Branch.update_subtree_size(btree, branch, branch.0[Branch.AC.SUBTREE_SIZE] + 1);
    };

    public func insert<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>, key : K, value : V) : ?V {
        let leaf = Methods.get_leaf_node(btree, mem_utils, key);

        let key_blob = mem_utils.0.to_blob(key);

        let int_index = switch (mem_utils.2) {
            case (#cmp(cmp)) MemoryFns.leaf_binary_search<K, V>(btree, mem_utils, leaf.2, cmp, key, leaf.0 [Leaf.AC.COUNT]);
            case (#blob_cmp(cmp)) {
                MemoryFns.leaf_binary_search_blob_seq(btree.blobs, leaf.2, cmp, key_blob, leaf.0 [Leaf.AC.COUNT]);
            };
        };

        let elem_index = if (int_index >= 0) Int.abs(int_index) else Int.abs(int_index + 1);

        let value_blob = mem_utils.1.to_blob(value);

        if (int_index >= 0) {
            // existing key
            let ?prev_block = leaf.2 [elem_index] else Debug.trap("insert: accessed a null value");
            let prev_blob_value = MemoryBlock.get_value(btree, prev_block);

            let mem_block = MemoryBlock.replace_kv(btree, prev_block, key_blob, value_blob);
            Leaf.put(btree, leaf, elem_index, mem_block);

            switch(leaf.1[Leaf.AC.PARENT]) {
                // update the median key since its location has changed
                case (?(parent_address)) if (elem_index == 0) {
                    let parent = Branch.from_address(btree, parent_address);
                    Branch.update_median_key(btree, parent, elem_index, (mem_block.0, mem_block.1));
                };
                case(null) {};
            };

            return ?mem_utils.1.from_blob(prev_blob_value);
        };

        let mem_block = MemoryBlock.store_kv(btree, key_blob, value_blob);

        if (leaf.0 [Leaf.AC.COUNT] < btree.order) {
            Leaf.insert(btree, leaf, elem_index, mem_block);
            update_count(btree, btree.count + 1);

            Methods.update_leaf_to_root(btree, leaf, inc_subtree_size_upstream);
            return null;
        };

        // split leaf
        let right = Leaf.split(btree, leaf, elem_index, mem_block);
        var opt_parent = leaf.1 [Leaf.AC.PARENT];
        let ?first_mb = right.2 [0] else Debug.trap("insert: accessed a null value");
        var right_key_ptr = (first_mb.0, first_mb.1);
        var right_index = right.0 [Leaf.AC.INDEX];
        var right_node : Node = #leaf(right);

        var left_node : Node = #leaf(leaf);
        assert leaf.0 [Leaf.AC.COUNT] == (btree.order / 2) + 1;
        assert right.0 [Leaf.AC.COUNT] == (btree.order / 2);
        
        while (Option.isSome(opt_parent)) {
        //  Debug.print("left leaf: " # debug_show left_node);
        //  Debug.print("right leaf: " # debug_show right_node);

            let ?parent_address = opt_parent else Debug.trap("insert: Failed to get parent address");
            let parent = Branch.from_address(btree, parent_address);

            // increment parent subtree size by 1 for the new key-value pair
            Branch.update_subtree_size(btree, parent, parent.0 [Branch.AC.SUBTREE_SIZE] + 1);

            // insert right node in parent if there is enough space
            if (parent.0 [Branch.AC.COUNT] < btree.order) {
            //  Debug.print("insert in MemoryBTree.insert()");
                
                Branch.insert(btree, parent, right_index, right_key_ptr, right_node);
                update_count(btree, btree.count + 1);
                
                Methods.update_branch_to_root(btree, parent, inc_subtree_size_upstream);
                return null;
            };

            // otherwise split parent 
            let left = parent;

            let right = Branch.split(btree, left, right_index, right_key_ptr, right_node);
            
            let ?first_key = ArrayMut.extract(right.2, right.2.size() - 1 : Nat) else Debug.trap("4. insert: accessed a null value in first key of branch");
            right_key_ptr := first_key;

            left_node := #branch(left);
            right_node := #branch(right);

            right_index := right.0[Branch.AC.INDEX];
            opt_parent := right.1[Branch.AC.PARENT];

        };

        // new root
        let new_root = Branch.new(btree);
        Branch.put_key(btree, new_root, 0, right_key_ptr);

        Branch.add_child(btree, new_root, left_node);
        Branch.add_child(btree, new_root, right_node);

        assert new_root.0[Branch.AC.COUNT] == 2;

        update_root(btree, #branch(new_root));
        update_count(btree, btree.count + 1);

    //  Debug.print("insert: " # debug_show new_root);

        null;
    };

    public func entries<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>) : RevIter<(K, V)> {
        Methods.entries(btree, mem_utils);
    };

    public func keys<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>) : RevIter<K> {
        Methods.keys(btree, mem_utils);
    };

    public func vals<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>) : RevIter<V> {
        Methods.vals(btree, mem_utils);
    };

    public func get<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>, key : K) : ?V {
        let leaf = Methods.get_leaf_node(btree, mem_utils, key);

        let key_blob = mem_utils.0.to_blob(key);

        let int_index = switch (mem_utils.2) {
            case (#cmp(cmp)) MemoryFns.leaf_binary_search<K, V>(btree, mem_utils, leaf.2, cmp, key, leaf.0 [Leaf.AC.COUNT]);
            case (#blob_cmp(cmp)) {
                MemoryFns.leaf_binary_search_blob_seq(btree.blobs, leaf.2, cmp, key_blob, leaf.0 [Leaf.AC.COUNT]);
            };
        };

        if (int_index < 0) return null;

        let elem_index = if (int_index >= 0) Int.abs(int_index) else Int.abs(int_index + 1);
        let ?mem_block = leaf.2 [elem_index] else Debug.trap("get: accessed a null value");

        let value_blob = MemoryBlock.get_value(btree, mem_block);
        let value = mem_utils.1.from_blob(value_blob);
        ?value;
    };

    public func getMin<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>) : ?(K, V) {
        let leaf = Methods.get_min_leaf(btree);

        let ?mem_block = leaf.2 [0] else return null;
        let key_blob = MemoryBlock.get_key(btree, mem_block);
        let value_blob = MemoryBlock.get_value(btree, mem_block);

        let key = mem_utils.0.from_blob(key_blob);
        let value = mem_utils.1.from_blob(value_blob);
        ?(key, value);
    };

    public func getMax<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>) : ?(K, V) {
        let leaf = Methods.get_max_leaf(btree);

        let ?mem_block = leaf.2 [leaf.0 [Leaf.AC.COUNT] - 1] else return null;
        let key_blob = MemoryBlock.get_key(btree, mem_block);
        let value_blob = MemoryBlock.get_value(btree, mem_block);

        let key = mem_utils.0.from_blob(key_blob);
        let value = mem_utils.1.from_blob(value_blob);
        ?(key, value);
    };

};
