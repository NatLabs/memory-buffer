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
import Itertools "mo:itertools/Iter";

import MemoryFns "./MemoryFns";
import Blobify "../Blobify";
import MemoryCmp "../MemoryCmp";
import Leaf "Leaf";
import Branch "./Branch";
import T "Types";
import ArrayMut "./ArrayMut";
import Methods "./Methods";
import MemoryBlock "./MemoryBlock";

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
            var branch_count = 0;
            var leaf_count = 0;

            metadata = MemoryRegion.new();
            blobs = MemoryRegion.new();

            nodes_cache = LruCache.new(CACHE_LIMIT);
        };

        init_region_header(btree_map);

        let leaf_address = Leaf.new(btree_map);
        update_root(btree_map, leaf_address);

        return btree_map;
    };

    public func new_set(order : ?Nat) : MemoryBTree {
        _new_with_options(order, true);
    };

    public func new(order : ?Nat) : MemoryBTree {
        _new_with_options(order, false);
    };

    public let BLOBS_REGION_HEADER_SIZE = 64;
    public let METADATA_REGION_HEADER_SIZE = 96;

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
        BRANCH_COUNT = 32;
        LEAF_COUNT = 40;
        BLOB_START = 64;
        NODES_START = 96;
    };

    func init_region_header(btree : MemoryBTree) {
        assert MemoryRegion.size(btree.blobs) == 0;
        assert MemoryRegion.size(btree.metadata) == 0;

        // Each Region has a 64 byte header
        ignore MemoryRegion.allocate(btree.blobs, BLOBS_REGION_HEADER_SIZE); // Reserved Space for the Region Header
        MemoryRegion.storeBlob(btree.blobs, MC.MAGIC_NUMBER_ADDRESS, "BLB"); // MAGIC NUMBER (BLB -> Blob Region) 3 bytes
        MemoryRegion.storeNat8(btree.blobs, MC.LAYOUT_VERSION_ADDRESS, Nat8.fromNat(LAYOUT_VERSION)); // |1 byte | Layout Version (1)
        MemoryRegion.storeNat32(btree.blobs, MC.REGION_ID_ADDRESS, Nat32.fromNat(MemoryRegion.id(btree.metadata))); // store the pointers region id in the blob region
        assert MemoryRegion.size(btree.blobs) == BLOBS_REGION_HEADER_SIZE;

        // | 64 byte header | -> 3 bytes + 1 byte + 8 bytes + 52 bytes
        ignore MemoryRegion.allocate(btree.metadata, METADATA_REGION_HEADER_SIZE); // Reserved Space for the Region Header
        MemoryRegion.storeBlob(btree.metadata, MC.MAGIC_NUMBER_ADDRESS, "BTR"); // |3 bytes| MAGIC NUMBER (BTM -> BTree Map Region)
        MemoryRegion.storeNat8(btree.metadata, MC.LAYOUT_VERSION_ADDRESS, Nat8.fromNat(LAYOUT_VERSION)); // |1 byte | Layout Version (1)
        MemoryRegion.storeNat32(btree.metadata, MC.REGION_ID_ADDRESS, Nat32.fromNat(MemoryRegion.id(btree.blobs))); // store the blobs region id in the pointers region
        MemoryRegion.storeNat16(btree.metadata, MC.ORDER_ADDRESS, Nat16.fromNat(btree.order)); // |2 bytes| Order -> Number of elements allowed in each node
        MemoryRegion.storeNat64(btree.metadata, MC.ROOT_ADDRESS, 0); // |8 bytes| Root -> Address of the root node
        MemoryRegion.storeNat64(btree.metadata, MC.COUNT_ADDRESS, 0); // |8 bytes| Count -> Number of elements in the buffer
        MemoryRegion.storeNat64(btree.metadata, MC.BRANCH_COUNT, 0); // |8 bytes| Branch Count -> Number of Branch Nodes
        MemoryRegion.storeNat64(btree.metadata, MC.LEAF_COUNT, 0); // |8 bytes| Leaf Count -> Number of Leaf Nodes
        assert MemoryRegion.size(btree.metadata) == METADATA_REGION_HEADER_SIZE;
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

    func update_branch_count(btree : MemoryBTree, new_count : Nat) {
        btree.branch_count := new_count;
        MemoryRegion.storeNat64(btree.metadata, MC.BRANCH_COUNT, Nat64.fromNat(new_count));
    };

    func update_leaf_count(btree : MemoryBTree, new_count : Nat) {
        btree.leaf_count := new_count;
        MemoryRegion.storeNat64(btree.metadata, MC.LEAF_COUNT, Nat64.fromNat(new_count));
    };

    func inc_subtree_size(btree : MemoryBTree, branch_address : Nat, _child_index : Nat) {
        let subtree_size = Branch.get_subtree_size(btree, branch_address);
        Branch.update_subtree_size(btree, branch_address, subtree_size + 1);
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
            let ?prev_val_block = Leaf.get_val_block(btree, leaf_address, elem_index) else Debug.trap("insert: accessed a null value");
            let ?prev_val_blob = Leaf.get_val_blob(btree, leaf_address, elem_index) else Debug.trap("insert: accessed a null value");

            let val_block = MemoryBlock.replace_val(btree, prev_val_block, val_blob);
            Leaf.put_val(btree, leaf_address, elem_index, val_block, val_blob);

            return ?mem_utils.1.from_blob(prev_val_blob);
        };

        let key_block = MemoryBlock.store_key(btree, key_blob);
        let val_block = MemoryBlock.store_val(btree, val_blob);

        if (count < btree.order) {
            Leaf.insert(btree, leaf_address, elem_index, key_block, key_blob, val_block, val_blob);
            update_count(btree, btree.count + 1);

            Methods.update_leaf_to_root(btree, leaf_address, inc_subtree_size);
            return null;
        };

        // split leaf
        var left_node_address = leaf_address;
        var right_node_address = Leaf.split(btree, left_node_address, elem_index, key_block, key_blob, val_block, val_blob);

        var opt_parent = Leaf.get_parent(btree, right_node_address);
        var right_index = Leaf.get_index(btree, right_node_address);

        let ?first_key_block = Leaf.get_key_block(btree, right_node_address, 0) else Debug.trap("insert: accessed a null value");
        let ?first_key_blob = Leaf.get_key_blob(btree, right_node_address, 0) else Debug.trap("insert: accessed a null value");
        var median_key_block = first_key_block;
        var median_key_blob = first_key_blob;


        assert Leaf.get_count(btree, left_node_address) == (btree.order / 2) + 1;
        assert Leaf.get_count(btree, right_node_address) == (btree.order / 2);
        
        while (Option.isSome(opt_parent)) {

            let ?parent_address = opt_parent else Debug.trap("insert: Failed to get parent address");

            // increment parent subtree size by 1 for the new key-value pair
            let prev_parent_subtree_size = Branch.get_subtree_size(btree, parent_address);
            Branch.update_subtree_size(btree, parent_address, prev_parent_subtree_size + 1);

            let parent_count = Branch.get_count(btree, parent_address);
            assert MemoryRegion.loadBlob(btree.metadata, parent_address, Branch.MC.MAGIC_SIZE) == Branch.MC.MAGIC;

            // insert right node in parent if there is enough space
            if (parent_count < btree.order) {

                Branch.insert(btree, parent_address, right_index, median_key_block, median_key_blob, right_node_address);
                update_count(btree, btree.count + 1);

                Methods.update_branch_to_root(btree, parent_address, inc_subtree_size);
                return null;
            };

            // otherwise split parent 
            left_node_address := parent_address;
            right_node_address := Branch.split(btree, left_node_address, right_index, median_key_block, median_key_blob, right_node_address);
            
            let ?first_key_block = Branch.get_key_block(btree, right_node_address, btree.order - 2) else Debug.trap("4. insert: accessed a null value in first key of branch");
            let ?first_key_blob = Branch.get_key_blob(btree, right_node_address, btree.order - 2) else Debug.trap("4. insert: accessed a null value in first key of branch");
            median_key_block := first_key_block;
            median_key_blob := first_key_blob;

            right_index := Branch.get_index(btree, right_node_address);
            opt_parent := Branch.get_parent(btree, right_node_address);

        };

        // new root
        let new_root = Branch.new(btree);

        Branch.put_key(btree, new_root, 0, median_key_block, median_key_blob);

        Branch.add_child(btree, new_root, left_node_address);
        Branch.add_child(btree, new_root, right_node_address);

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
        let count = Leaf.get_count(btree, leaf_address);

        let int_index = switch (mem_utils.2) {
            case (#cmp(cmp)) Leaf.binary_search<K, V>(btree, mem_utils, leaf_address, cmp, key, count);
            case (#blob_cmp(cmp)) {
                Leaf.binary_search_blob_seq(btree, leaf_address, cmp, key_blob, count);
            };
        };

        if (int_index < 0) return null;

        let elem_index = Int.abs(int_index);
        
        let ?val_blob = Leaf.get_val_blob(btree, leaf_address, elem_index) else Debug.trap("get: accessed a null value");
        let value = mem_utils.1.from_blob(val_blob);
        ?value;
    };

    // public func get_block<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>, key : K) : ?MemoryBlock {
    //     let key_blob = mem_utils.0.to_blob(key);

    //     let leaf_address = Methods.get_leaf_address(btree, mem_utils, key, ?key_blob);
    //     let count = Leaf.get_count(btree, leaf_address);

    //     let int_index = switch (mem_utils.2) {
    //         case (#cmp(cmp)) Leaf.binary_search<K, V>(btree, mem_utils, leaf_address, cmp, key, count);
    //         case (#blob_cmp(cmp)) {
    //             Leaf.binary_search_blob_seq(btree, leaf_address, cmp, key_blob, count);
    //         };
    //     };

    //     if (int_index < 0) return null;

    //     let elem_index = Int.abs(int_index);
        
    //     let ?comp_val = Leaf.get_val(btree, leaf_address, elem_index)else Debug.trap("get: accessed a null value");
    //     ?(comp_val.0)
    // };

    public func getMin<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>) : ?(K, V) {
        let leaf_address = Methods.get_min_leaf_address(btree);

        let ?key_blob = Leaf.get_key_blob(btree, leaf_address, 0) else Debug.trap("getMin: accessed a null value");
        let ?val_blob = Leaf.get_val_blob(btree, leaf_address, 0) else Debug.trap("getMin: accessed a null value");

        let key = mem_utils.0.from_blob(key_blob);
        let value = mem_utils.1.from_blob(val_blob);
        ?(key, value);
    };

    public func getMax<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>) : ?(K, V) {
        let leaf_address = Methods.get_max_leaf_address(btree);
        let count = Leaf.get_count(btree, leaf_address);

        let ?key_blob = Leaf.get_key_blob(btree, leaf_address, count - 1 : Nat) else Debug.trap("getMax: accessed a null value");
        let ?val_blob = Leaf.get_val_blob(btree, leaf_address, count - 1 : Nat) else Debug.trap("getMax: accessed a null value");

        let key = mem_utils.0.from_blob(key_blob);
        let value = mem_utils.1.from_blob(val_blob);
        ?(key, value);
    };

    public func clear(btree: MemoryBTree) {
        // the first leaf node should be at the address where the header ends
        let leaf_address = MC.NODES_START;
        assert Leaf.validate(btree, leaf_address);

        Leaf.clear(btree, leaf_address);
        assert Leaf.validate(btree, leaf_address);

        update_root(btree, leaf_address);
        update_count(btree, 0);
        update_branch_count(btree, 0);
        update_leaf_count(btree, 1);

        // Debug.print("blobs size: " # debug_show MemoryRegion.size(btree.blobs));

        var prev_size = BLOBS_REGION_HEADER_SIZE;
        for ((mem_block) in MemoryRegion.getFreeMemory(btree.blobs).vals()){
            assert prev_size <= mem_block.0;
            MemoryRegion.deallocate(btree.blobs, prev_size, mem_block.0 - prev_size);
            prev_size := mem_block.0 + mem_block.1;
        };

        if (prev_size < MemoryRegion.size(btree.blobs)) {
            MemoryRegion.deallocate(btree.blobs, prev_size, MemoryRegion.size(btree.blobs) - prev_size);
        };

        assert MemoryRegion.allocated(btree.blobs) == BLOBS_REGION_HEADER_SIZE;

        let leaf_memory_size = Leaf.get_memory_size(btree);

        let everything_after_leaf = leaf_address + leaf_memory_size;

        prev_size := everything_after_leaf;
        for ((mem_block) in MemoryRegion.getFreeMemory(btree.metadata).vals()){
            assert prev_size <= mem_block.0;
            MemoryRegion.deallocate(btree.metadata, prev_size, mem_block.0 - prev_size);
            prev_size := mem_block.0 + mem_block.1;
        };

        if (prev_size < MemoryRegion.size(btree.metadata)) {
            MemoryRegion.deallocate(btree.metadata, prev_size, MemoryRegion.size(btree.metadata) - prev_size);
        };

        // Debug.print("leaf_memory_size: " # debug_show leaf_memory_size);
        // Debug.print("metadata size: " # debug_show MemoryRegion.allocated(btree.metadata));
        
        // Debug.print("metadata size after: " # debug_show MemoryRegion.allocated(btree.metadata));
        assert MemoryRegion.allocated(btree.metadata) == everything_after_leaf;
    };

};
