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

        let node = #leaf(leaf);
        update_root(btree_map, leaf.0 [Leaf.AC.ADDRESS]);

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
        MemoryRegion.storeBlob(btree.metadata, MC.MAGIC_NUMBER_ADDRESS, "BTR"); // |3 bytes| MAGIC NUMBER (BTM -> BTree Map Region)
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

    func update_root(btree : MemoryBTree, new_root : Address) {
        btree.root := new_root;
        MemoryRegion.storeNat64(btree.metadata, MC.ROOT_ADDRESS, Nat64.fromNat(new_root));
    };

    func update_count(btree : MemoryBTree, new_count : Nat) {
        btree.count := new_count;
        MemoryRegion.storeNat64(btree.metadata, MC.COUNT_ADDRESS, Nat64.fromNat(new_count));
    };

    func inc_subtree_size_from_address_upstream(btree: MemoryBTree, branch_address: Nat, _child_index: Nat) {
        let subtree_size = Branch.get_subtree_size(btree, branch_address);
        Branch.partial_update_subtree_size(btree, branch_address, subtree_size + 1);
    };

    func inc_subtree_size_upstream(btree: MemoryBTree, branch: Branch, _child_index: Nat) {
        Branch.update_subtree_size(btree, branch, branch.0[Branch.AC.SUBTREE_SIZE] + 1);
    };

    func partial_inc_subtree_size(btree : MemoryBTree, branch_address : Nat, _child_index : Nat) {
        let subtree_size = Branch.get_subtree_size(btree, branch_address);
        Branch.partial_update_subtree_size(btree, branch_address, subtree_size + 1);
    };

    public func insert<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>, key : K, value : V) : ?V {
        let key_blob = mem_utils.0.to_blob(key);

        let leaf_address = Methods.get_leaf_address(btree, mem_utils, key, ?key_blob);
        let count = Leaf.get_count(btree, leaf_address);

        let int_index = switch (mem_utils.2) {
            case (#cmp(cmp)) Leaf.binary_search<K, V>(btree, mem_utils, leaf_address, cmp, key, count);
            case (#blob_cmp(cmp)) {
                Leaf.binary_search_blob_seq(btree, leaf_address, cmp, key_blob, count);
            };
        };

        let elem_index = if (int_index >= 0) Int.abs(int_index) else Int.abs(int_index + 1);

        let val_blob = mem_utils.1.to_blob(value);

        if (int_index >= 0) {
            // existing key
            let ?prev = Leaf.get_val(btree, leaf_address, elem_index) else Debug.trap("insert: accessed a null value");
            let prev_block = prev.0;
            let prev_val = prev.1;

            let val_block = MemoryBlock.replace_val(btree, prev_block, val_blob);
            let composite_val = (val_block, val_blob);
            Leaf.partial_put_val(btree, leaf_address, elem_index, composite_val);

            return ?mem_utils.1.from_blob(prev_val);
        };

        let key_block = MemoryBlock.store_key(btree, key_blob);
        let val_block = MemoryBlock.store_val(btree, val_blob);

        let comp_key = (key_block, key_blob);
        let comp_val = (val_block, val_blob);

        if (count < btree.order) {
            Leaf.partial_insert(btree, leaf_address, elem_index, comp_key, comp_val);
            update_count(btree, btree.count + 1);

            Methods.partial_update_leaf_to_root(btree, leaf_address, inc_subtree_size_from_address_upstream);
            return null;
        };

        // split leaf
        var left_node_address = leaf_address;
        var right_node_address = Leaf.partial_split(btree, left_node_address, elem_index, comp_key, comp_val);

        var opt_parent = Leaf.get_parent(btree, right_node_address);
        let ?first_key = Leaf.get_key(btree, right_node_address, 0) else Debug.trap("insert: accessed a null value");
        var median_key = first_key;
        var right_index = Leaf.get_index(btree, right_node_address);

        assert Leaf.get_count(btree, left_node_address) == (btree.order / 2) + 1;
        assert Leaf.get_count(btree, right_node_address) == (btree.order / 2);
        
        while (Option.isSome(opt_parent)) {

            let ?parent_address = opt_parent else Debug.trap("insert: Failed to get parent address");

            // increment parent subtree size by 1 for the new key-value pair
            let prev_parent_subtree_size = Branch.get_subtree_size(btree, parent_address);
            Branch.partial_update_subtree_size(btree, parent_address, prev_parent_subtree_size + 1);

            let parent_count = Branch.get_count(btree, parent_address);
            assert MemoryRegion.loadBlob(btree.metadata, parent_address, Branch.MC.MAGIC_SIZE) == Branch.MC.MAGIC;

            // insert right node in parent if there is enough space
            if (parent_count < btree.order) {

                Branch.partial_insert(btree, parent_address, right_index, median_key, right_node_address);
                update_count(btree, btree.count + 1);

                Methods.partial_update_branch_to_root(btree, parent_address, partial_inc_subtree_size);
                return null;
            };

            // otherwise split parent 
            left_node_address := parent_address;
            right_node_address := Branch.partial_split(btree, left_node_address, right_index, median_key, right_node_address);
            
            let ?first_key = Branch.get_key(btree, right_node_address, btree.order - 2) else Debug.trap("4. insert: accessed a null value in first key of branch");
            median_key := first_key;

            right_index := Branch.get_index(btree, right_node_address);
            opt_parent := Branch.get_parent(btree, right_node_address);

        };

        // new root
        let new_root = Branch.partial_new(btree);

        Branch.partial_put_key(btree, new_root, 0, median_key);

        Branch.partial_add_child(btree, new_root, left_node_address);
        Branch.partial_add_child(btree, new_root, right_node_address);

        assert Branch.get_count(btree, new_root) == 2;

        update_root(btree, new_root);
        update_count(btree, btree.count + 1);


        null;
    };

    public func blocks(btree: MemoryBTree) : RevIter<(Blob, Blob)> {
        Methods.blocks(btree);
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
        let key_blob = mem_utils.0.to_blob(key);

        let leaf_address = Methods.get_leaf_address(btree, mem_utils, key, ?key_blob);
        let keys = Leaf.get_keys(btree, leaf_address);
        let count = Leaf.get_count(btree, leaf_address);

        let int_index = switch (mem_utils.2) {
            case (#cmp(cmp)) Leaf.binary_search<K, V>(btree, mem_utils, leaf_address, cmp, key, count);
            case (#blob_cmp(cmp)) {
                Leaf.binary_search_blob_seq(btree, leaf_address, cmp, key_blob, count);
            };
        };

        if (int_index < 0) return null;

        let elem_index = Int.abs(int_index);
        
        let ?comp_val = Leaf.get_val(btree, leaf_address, elem_index)else Debug.trap("get: accessed a null value");
        let val_blob = comp_val.1;
        let value = mem_utils.1.from_blob(val_blob);
        ?value;
    };

    // public func get_block<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>, key : K) : ?MemoryBlock {
    //     let key_blob = mem_utils.0.to_blob(key);

    //     let leaf = Methods.get_leaf_node(btree, mem_utils, key, ?key_blob);

    //     let int_index = switch (mem_utils.2) {
    //         case (#cmp(cmp)) MemoryFns.binary_search<K, V>(btree, mem_utils, leaf.2, cmp, key, leaf.0 [Leaf.AC.COUNT]);
    //         case (#blob_cmp(cmp)) {
    //             MemoryFns.binary_search_blob_seq(btree, leaf.2, cmp, key_blob, leaf.0 [Leaf.AC.COUNT]);
    //         };
    //     };

    //     if (int_index < 0) return null;

    //     let elem_index = Int.abs(int_index);
        
    //     leaf.2 [elem_index];
    // };

    public func getMin<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>) : ?(K, V) {
        let leaf = Methods.get_min_leaf(btree);

        let ?(key_block, key_blob) = leaf.2 [0] else return null;
        let ?(val_block, val_blob) = leaf.3 [0] else return null;

        let key = mem_utils.0.from_blob(key_blob);
        let value = mem_utils.1.from_blob(val_blob);
        ?(key, value);
    };

    public func getMax<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>) : ?(K, V) {
        let leaf = Methods.get_max_leaf(btree);

        let ?(key_block, key_blob) = leaf.2 [leaf.0 [Leaf.AC.COUNT] - 1] else return null;
        let ?(val_block, val_blob) = leaf.3 [leaf.0 [Leaf.AC.COUNT] - 1] else return null;

        let key = mem_utils.0.from_blob(key_blob);
        let value = mem_utils.1.from_blob(val_blob);
        ?(key, value);
    };

};
