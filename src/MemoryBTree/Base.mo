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

module {
    type Address = Nat;
    type MemoryRegion = MemoryRegion.MemoryRegion;
    type LruCache<K, V> = LruCache.LruCache<K, V>;
    type Blobify<A> = Blobify.Blobify<A>;
    type RevIter<A> = RevIter.RevIter<A>;

    public type MemoryCmp<A> = MemoryCmp.MemoryCmp<A>;

    public type MemoryBTree = T.MemoryBTree;
    public type Node = T.Node;
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
            Debug.trap("get_node: branch nodes not implemented");
        };

        LruCache.put(btree.nodes_cache, nhash, node_address, node);
        node;
    };

    public func get_leaf_node<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>, key : K) : Leaf.Leaf {
        var curr = ?get_node(btree, btree.root);

        loop {
            switch (curr) {
                case (? #branch(node)) {
                    let int_index = switch (mem_utils.2) {
                        case (#cmp(cmp)) Debug.trap("get_leaf_node: cmp not implemented");
                        case (#blob_cmp(cmp)) {
                            let key_blob = mem_utils.0.to_blob(key);
                            MemoryFns.binary_search(btree.blobs, node.2, cmp, key_blob, node.0 [Branch.AC.COUNT] - 1);
                        };
                    };

                    let node_index = if (int_index >= 0) Int.abs(int_index) + 1 else Int.abs(int_index + 1);
                    let ?node_address = node.3 [node_index] else Debug.trap("get_leaf_node: accessed a null value");
                    curr := ?get_node(btree, node_address);
                };
                case (? #leaf(leaf_node)) return leaf_node;
                case (_) Debug.trap("get_leaf_node: accessed a null value");
            };
        };
    };

    func store_kv_in_memory(btree : MemoryBTree, key : Blob, value : Blob) : MemoryBlock {
        let mb_address = MemoryRegion.allocate(btree.blobs, key.size() + value.size());
        MemoryRegion.storeBlob(btree.blobs, mb_address, key);
        MemoryRegion.storeBlob(btree.blobs, mb_address + Leaf.MAX_KEY_SIZE, value);

        (mb_address, key.size(), value.size());
    };

    func replace_kv_in_memory(btree : MemoryBTree, prev_block : MemoryBlock, key : Blob, value : Blob) : (Nat, Nat, Nat) {
        let new_mb_address = MemoryRegion.resize(btree.blobs, prev_block.0, prev_block.1, key.size() + value.size());
        MemoryRegion.storeBlob(btree.blobs, new_mb_address, key);
        MemoryRegion.storeBlob(btree.blobs, new_mb_address + Leaf.MAX_KEY_SIZE, value);

        (new_mb_address, key.size(), value.size());
    };

    public func insert<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>, key : K, value : V) : ?V {
        let leaf = get_leaf_node(btree, mem_utils, key);

        let key_blob = mem_utils.0.to_blob(key);

        let int_index = switch (mem_utils.2) {
            case (#cmp(cmp)) Debug.trap("insert: cmp not implemented");
            case (#blob_cmp(cmp)) {
                MemoryFns.leaf_binary_search(btree.blobs, leaf.2, cmp, key_blob, leaf.0 [Leaf.AC.COUNT]);
            };
        };

        let elem_index = if (int_index >= 0) Int.abs(int_index) else Int.abs(int_index + 1);

        let value_blob = mem_utils.1.to_blob(value);

        if (int_index >= 0) {
            // existing key
            let ?prev_block = leaf.2 [elem_index] else Debug.trap("insert: accessed a null value");
            let prev_blob_value = MemoryRegion.loadBlob(btree.blobs, prev_block.0 + Leaf.MAX_KEY_SIZE, prev_block.2);

            let mem_block = replace_kv_in_memory(btree, prev_block, key_blob, value_blob);
            Leaf.put(btree, leaf, elem_index, mem_block);
            return ?mem_utils.1.from_blob(prev_blob_value);
        };

        let mem_block = store_kv_in_memory(btree, key_blob, value_blob);

        if (leaf.0 [Leaf.AC.COUNT] < btree.order) {
            Leaf.insert(btree, leaf, elem_index, mem_block);
            update_count(btree, btree.count + 1);
            return null;
        };

        // split leaf
        let right = Leaf.split(btree, leaf, elem_index, mem_block);
        var opt_parent = leaf.1 [Leaf.AC.PARENT];
        let ?first_mb = right.2 [0] else Debug.trap("insert: accessed a null value");
        var right_key_ptr = (first_mb.0, first_mb.1);

        while (Option.isSome(opt_parent)) {

        };

        // new root
        let new_root = Branch.new(btree);
        Branch.put_key(btree, new_root, 0, right_key_ptr);

        Branch.add_child(btree, new_root, leaf.0 [Leaf.AC.ADDRESS]);
        Branch.add_child(btree, new_root, right.0 [Leaf.AC.ADDRESS]);

        update_root(btree, #branch(new_root));
        update_count(btree, btree.count + 1);

        Debug.print("insert: " # debug_show new_root);

        null;
    };
    
};
