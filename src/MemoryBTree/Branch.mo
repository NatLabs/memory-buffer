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
import Order "mo:base/Order";

import MemoryRegion "mo:memory-region/MemoryRegion";
import LruCache "mo:lru-cache";
import RevIter "mo:itertools/RevIter";
// import Branch "mo:augmented-btrees/BpTree/Branch";

import MemoryFns "./MemoryFns";
import Blobify "../Blobify";
import MemoryCmp "../MemoryCmp";
import ArrayMut "ArrayMut";
import T "Types";
import Leaf "Leaf";
import MemoryBlock "MemoryBlock";

module Branch {

    type MemoryRegion = MemoryRegion.MemoryRegion;
    type LruCache<K, V> = LruCache.LruCache<K, V>;
    type Blobify<A> = Blobify.Blobify<A>;
    type RevIter<A> = RevIter.RevIter<A>;
    type MemoryUtils<K, V> = T.MemoryUtils<K, V>;
    type MemoryBTree = T.MemoryBTree;
    type MemoryBlock = T.MemoryBlock;
    type Node = T.Node;
    type Address = T.Address;
    type NodeType = T.NodeType;

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
        MAGIC_START = 0;
        MAGIC_SIZE = 3;

        LAYOUT_VERSION_START = 3;
        LAYOUT_VERSION_SIZE = 1;

        NODE_TYPE_START = 4;
        NODE_TYPE_SIZE = 1;

        INDEX_START = 5;
        INDEX_SIZE = 2;

        COUNT_START = 7;
        COUNT_SIZE = 2;

        SUBTREE_COUNT_START = 9;
        SUBTREE_COUNT_SIZE = 8;

        PARENT_START = 17;
        ADDRESS_SIZE = 8;

        KEYS_START = 25;
        MAX_KEY_SIZE = 2;

        NULL_ADDRESS : Nat64 = 0x00;

        MAGIC : Blob = "BTN";
        LAYOUT_VERSION : Nat8 = 0;
        NODE_TYPE : Nat8 = 0x00; // branch node
    };

    public func get_memory_size(btree : MemoryBTree) : Nat {
        let bytes_per_node = Branch.MC.MAGIC_SIZE // magic
        + Branch.MC.LAYOUT_VERSION_SIZE // layout version
        + Branch.MC.NODE_TYPE_SIZE // node type
        + Branch.MC.ADDRESS_SIZE // parent address
        + Branch.MC.INDEX_SIZE // Node's position in parent node
        + Branch.MC.SUBTREE_COUNT_SIZE // number of elements in the node
        + Branch.MC.COUNT_SIZE // number of elements in the node
        // key pointers
        + (
            (
                Branch.MC.ADDRESS_SIZE // address of memory block
                + Branch.MC.MAX_KEY_SIZE // key size
            ) * (btree.order - 1 : Nat)
        )
        // children nodes
        + (Branch.MC.ADDRESS_SIZE * btree.order);

        bytes_per_node;
    };

    public func CHILDREN_START(btree : MemoryBTree) : Nat {
        MC.KEYS_START + ((btree.order - 1) * (MC.MAX_KEY_SIZE + MC.ADDRESS_SIZE));
    };

    public func get_key_offset(branch_address : Nat, i : Nat) : Nat {
        branch_address + MC.KEYS_START + (i * (MC.MAX_KEY_SIZE + MC.ADDRESS_SIZE));
    };

    public func get_child_offset(btree : MemoryBTree, branch_address : Nat, i : Nat) : Nat {
        branch_address + CHILDREN_START(btree) + (i * MC.ADDRESS_SIZE);
    };

    public func new(btree : MemoryBTree) : Branch {
        let bytes_per_node = Branch.get_memory_size(btree);

        let branch_address = MemoryRegion.allocate(btree.metadata, bytes_per_node);

        MemoryRegion.storeBlob(btree.metadata, branch_address, MC.MAGIC);
        MemoryRegion.storeNat8(btree.metadata, branch_address + MC.LAYOUT_VERSION_START, MC.LAYOUT_VERSION);
        MemoryRegion.storeNat8(btree.metadata, branch_address + MC.NODE_TYPE_START, MC.NODE_TYPE);

        MemoryRegion.storeNat16(btree.metadata, branch_address + MC.INDEX_START, 0);
        MemoryRegion.storeNat16(btree.metadata, branch_address + MC.COUNT_START, 0);
        MemoryRegion.storeNat64(btree.metadata, branch_address + MC.SUBTREE_COUNT_START, 0);

        MemoryRegion.storeNat64(btree.metadata, branch_address + MC.PARENT_START, MC.NULL_ADDRESS);

        var i = 0;

        while (i < (btree.order - 1 : Nat)) {
            let key_offset = get_key_offset(branch_address, i);
            MemoryRegion.storeNat64(btree.metadata, key_offset, MC.NULL_ADDRESS);
            MemoryRegion.storeNat16(btree.metadata, key_offset + MC.ADDRESS_SIZE, Nat16.fromNat(0));
            i += 1;
        };

        i := 0;

        while (i < btree.order) {
            let child_offset = get_child_offset(btree, branch_address, i);
            MemoryRegion.storeNat64(btree.metadata, child_offset, MC.NULL_ADDRESS);
            i += 1;
        };

        let branch : Branch = (
            [var branch_address, 0, 0, 0],
            [var null],
            Array.init(btree.order - 1, null),
            Array.init<?Nat>(btree.order, null),
        );

        LruCache.put(btree.nodes_cache, nhash, branch.0 [AC.ADDRESS], #branch(branch));

        branch;
    };

    public func partial_new(btree : MemoryBTree) : Nat {
        let bytes_per_node = Branch.get_memory_size(btree);

        let branch_address = MemoryRegion.allocate(btree.metadata, bytes_per_node);

        MemoryRegion.storeBlob(btree.metadata, branch_address, MC.MAGIC);
        MemoryRegion.storeNat8(btree.metadata, branch_address + MC.LAYOUT_VERSION_START, MC.LAYOUT_VERSION);
        MemoryRegion.storeNat8(btree.metadata, branch_address + MC.NODE_TYPE_START, MC.NODE_TYPE);

        MemoryRegion.storeNat16(btree.metadata, branch_address + MC.INDEX_START, 0);
        MemoryRegion.storeNat16(btree.metadata, branch_address + MC.COUNT_START, 0);
        MemoryRegion.storeNat64(btree.metadata, branch_address + MC.SUBTREE_COUNT_START, 0);

        MemoryRegion.storeNat64(btree.metadata, branch_address + MC.PARENT_START, MC.NULL_ADDRESS);

        var i = 0;

        while (i < (btree.order - 1 : Nat)) {
            let key_offset = get_key_offset(branch_address, i);
            MemoryRegion.storeNat64(btree.metadata, key_offset, MC.NULL_ADDRESS);
            MemoryRegion.storeNat16(btree.metadata, key_offset + MC.ADDRESS_SIZE, Nat16.fromNat(0));
            i += 1;
        };

        i := 0;

        while (i < btree.order) {
            let child_offset = get_child_offset(btree, branch_address, i);
            MemoryRegion.storeNat64(btree.metadata, child_offset, MC.NULL_ADDRESS);
            i += 1;
        };

        branch_address;
    };

    func read_keys_into(btree : MemoryBTree, branch_address : Nat, keys : [var ?(MemoryBlock, Blob)]) {
        var i = 0;

        label while_loop while (i < (btree.order - 1)) {
            let key_offset = get_key_offset(branch_address, i);

            let key_address = MemoryRegion.loadNat64(btree.metadata, key_offset);

            if (key_address == MC.NULL_ADDRESS) break while_loop;

            let key_size = MemoryRegion.loadNat16(btree.metadata, key_offset + MC.ADDRESS_SIZE) |> Nat16.toNat(_);
            let key_block = (Nat64.toNat(key_address), key_size);
            let key_blob = MemoryBlock.get_key(btree, key_block);
            let key = (key_block, key_blob);

            keys[i] := ?key;
            i += 1;
        };
    };

    public func from_memory(btree : MemoryBTree, branch_address : Address) : Branch {
        assert MemoryRegion.loadBlob(btree.metadata, branch_address, MC.MAGIC_SIZE) == MC.MAGIC;
        assert MemoryRegion.loadNat8(btree.metadata, branch_address + MC.LAYOUT_VERSION_START) == MC.LAYOUT_VERSION;
        assert MemoryRegion.loadNat8(btree.metadata, branch_address + MC.NODE_TYPE_START) == MC.NODE_TYPE;

        let index = MemoryRegion.loadNat16(btree.metadata, branch_address + MC.INDEX_START) |> Nat16.toNat(_);
        let count = MemoryRegion.loadNat16(btree.metadata, branch_address + MC.COUNT_START) |> Nat16.toNat(_);
        let subtree_size = MemoryRegion.loadNat64(btree.metadata, branch_address + MC.SUBTREE_COUNT_START) |> Nat64.toNat(_);

        let parent = do {
            let p = MemoryRegion.loadNat64(btree.metadata, branch_address + MC.PARENT_START);
            if (p == MC.NULL_ADDRESS) null else ?Nat64.toNat(p);
        };

        let branch : Branch = (
            [var branch_address, index, count, subtree_size],
            [var parent],
            Array.init(btree.order - 1, null),
            Array.init<?Nat>(btree.order, null),
        );

        read_keys_into(btree, branch_address, branch.2);

        var i = 0;

        label while_loop2 while (i < btree.order) {
            let child_offset = get_child_offset(btree, branch_address, i);

            let child_address = MemoryRegion.loadNat64(btree.metadata, child_offset);

            if (child_address == MC.NULL_ADDRESS) break while_loop2;

            branch.3 [i] := ?Nat64.toNat(child_address);
            i += 1;
        };

        branch;
    };

    public func from_address(btree : MemoryBTree, address : Address, update_cache : Bool) : Branch {
        let opt_node = if (update_cache) {
            LruCache.get(btree.nodes_cache, nhash, address);
        } else {
            LruCache.peek(btree.nodes_cache, nhash, address);
        };

        switch (opt_node) {
            case (? #branch(branch)) return branch;
            case (null) {};
            case (? #leaf(_)) Debug.trap("Branch.from_address(): Expected a branch, got a leaf");
        };

        let branch = Branch.from_memory(btree, address);
        if (update_cache) LruCache.put(btree.nodes_cache, nhash, address, #branch(branch));
        branch;
    };

    public func add_to_cache(btree : MemoryBTree, address : Nat) {
        switch (LruCache.get(btree.nodes_cache, nhash, address)) {
            case (? #branch(_)) return;
            case (?#leaf(_)) Debug.trap("Branch.add_to_cache(): Expected a branch, got a leaf");
            case (_) {};
        };

        let branch = Branch.from_memory(btree, address);
        LruCache.put(btree.nodes_cache, nhash, address, #branch(branch));
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

    public func update_parent(btree : MemoryBTree, branch : Branch, opt_parent : ?Nat) {
        let parent = switch (opt_parent) {
            case (null) MC.NULL_ADDRESS;
            case (?_parent) Nat64.fromNat(_parent);
        };

        branch.1 [AC.PARENT] := opt_parent;
        MemoryRegion.storeNat64(btree.metadata, branch.0 [AC.ADDRESS] + MC.PARENT_START, parent);
    };

    public func partial_update_index(btree : MemoryBTree, branch_address : Nat, new_index : Nat) {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) branch.0 [AC.INDEX] := new_index;
            case (? #leaf(_)) Debug.trap("Branch.partial_update_index(): Expected a branch, got a leaf");
            case (_) {};
        };

        MemoryRegion.storeNat16(btree.metadata, branch_address + MC.INDEX_START, Nat16.fromNat(new_index));
    };

    public func put_key(btree : MemoryBTree, branch : Branch, i : Nat, key : (MemoryBlock, Blob)) {
        assert i < (btree.order - 1 : Nat);

        branch.2 [i] := ?key;
        let key_block = key.0;

        let offset = branch.0 [AC.ADDRESS] + MC.KEYS_START + (i * (MC.MAX_KEY_SIZE + MC.ADDRESS_SIZE));
        MemoryRegion.storeNat64(btree.metadata, offset, Nat64.fromNat(key_block.0));
        MemoryRegion.storeNat16(btree.metadata, offset + MC.ADDRESS_SIZE, Nat16.fromNat(key_block.1));
    };

    public func partial_put_key(btree : MemoryBTree, branch_address : Nat, i : Nat, key : (MemoryBlock, Blob)) {
        assert i < (btree.order - 1 : Nat);

        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) {
                branch.2 [i] := ?key;
            };
            case (? #leaf(_)) Debug.trap("Branch.partial_put_key(): Expected a branch, got a leaf");
            case (_) {};
        };

        let key_block = key.0;

        let offset = branch_address + MC.KEYS_START + (i * (MC.MAX_KEY_SIZE + MC.ADDRESS_SIZE));
        MemoryRegion.storeNat64(btree.metadata, offset, Nat64.fromNat(key_block.0));
        MemoryRegion.storeNat16(btree.metadata, offset + MC.ADDRESS_SIZE, Nat16.fromNat(key_block.1));
    };

    public func get_node_subtree_size(btree : MemoryBTree, node_address : Address) : Nat {
        switch (Branch.get_node_type(btree, node_address)) {
            case (#branch) {
                Branch.get_subtree_size(btree, node_address);
            };
            case (#leaf) {
                Leaf.get_count(btree, node_address);
            };
        };
    };

    public func add_child(btree : MemoryBTree, branch : Branch, i : Nat, node : Node) {
        assert i < btree.order;

        let child_address = switch (node) {
            case (#leaf(child)) {
                assert MemoryRegion.loadBlob(btree.metadata, child.0 [AC.ADDRESS], Leaf.MAGIC_SIZE) == Leaf.MAGIC;
                Leaf.update_parent(btree, child, ?branch.0 [AC.ADDRESS]);
                Leaf.update_index(btree, child, i);

                Branch.update_subtree_size(btree, branch, branch.0 [AC.SUBTREE_SIZE] + child.0 [Leaf.AC.COUNT]);
                child.0 [AC.ADDRESS];
            };
            case (#branch(child)) {
                assert MemoryRegion.loadBlob(btree.metadata, child.0 [AC.ADDRESS], Branch.MC.MAGIC_SIZE) == Branch.MC.MAGIC;

                Branch.update_parent(btree, child, ?branch.0 [AC.ADDRESS]);
                Branch.update_index(btree, child, i);

                Branch.update_subtree_size(btree, branch, branch.0 [AC.SUBTREE_SIZE] + child.0 [AC.SUBTREE_SIZE]);
                child.0 [AC.ADDRESS];
            };
        };

        branch.3 [i] := ?(child_address);

        let offset = get_child_offset(btree, branch.0 [AC.ADDRESS], i);
        MemoryRegion.storeNat64(btree.metadata, offset, Nat64.fromNat(child_address));

        Branch.update_count(btree, branch, branch.0[AC.COUNT] + 1);

    };

    public func partial_add_child(btree : MemoryBTree, branch_address : Nat, child_address : Nat) {

        let count = Branch.get_count(btree, branch_address);

        assert count < btree.order;

        switch (Branch.get_node_type(btree, child_address)) {
            case (#branch) {
                Branch.partial_update_parent(btree, child_address, ?branch_address);
                Branch.partial_update_index(btree, child_address, count);
            };
            case (#leaf) {
                Leaf.partial_update_parent(btree, child_address, ?branch_address);
                Leaf.partial_update_index(btree, child_address, count);
            };
        };

        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) {
                branch.3 [count] := ?child_address;
            };
            case (? #leaf(_)) Debug.trap("Branch.partial_put_child(): Expected a branch, got a leaf");
            case (_) {};
        };

        let offset = get_child_offset(btree, branch_address, count);
        MemoryRegion.storeNat64(btree.metadata, offset, Nat64.fromNat(child_address));

        let child_subtree_size = Branch.get_node_subtree_size(btree, child_address);
        let prev_subtree_size = Branch.get_subtree_size(btree, branch_address);
        Branch.partial_update_subtree_size(btree, branch_address, prev_subtree_size + child_subtree_size);
        Branch.partial_update_count(btree, branch_address, count + 1);
    };

    public func get_node(btree : MemoryBTree, node_address : Nat) : Node {
        switch (LruCache.get(btree.nodes_cache, nhash, node_address)) {
            case (?node) return node;
            case (_) {};
        };

        assert MemoryRegion.loadBlob(btree.metadata, node_address, MC.MAGIC_SIZE) == MC.MAGIC;

        let node_type = MemoryRegion.loadNat8(btree.metadata, node_address + MC.NODE_TYPE_START);

        let node = if (node_type == Branch.MC.NODE_TYPE) {
            #branch(Branch.from_address(btree, node_address, true));
        } else {
            #leaf(Leaf.from_address(btree, node_address, true));
        };

        node;
    };

    public func get_node_type(btree : MemoryBTree, node_address : Nat) : NodeType {
        switch (LruCache.peek(btree.nodes_cache, nhash, node_address)) {
            case (? #branch(_)) return #branch;
            case (? #leaf(_)) return #leaf;
            case (_) {};
        };
        assert MemoryRegion.loadBlob(btree.metadata, node_address, MC.MAGIC_SIZE) == MC.MAGIC;

        let node_type = MemoryRegion.loadNat8(btree.metadata, node_address + MC.NODE_TYPE_START);

        if (node_type == Branch.MC.NODE_TYPE) {
            #branch;
        } else {
            #leaf;
        };
    };

    public func get_count(btree : MemoryBTree, branch_address : Nat) : Nat {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) return branch.0 [AC.COUNT];
            case (? #leaf(leaf)) Debug.trap("Branch.get_child(): Expected a branch, got a leaf");
            case (_) {};
        };

        MemoryRegion.loadNat16(btree.metadata, branch_address + MC.COUNT_START) |> Nat16.toNat(_);
    };

    public func get_index(btree : MemoryBTree, branch_address : Nat) : Nat {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) return branch.0 [AC.INDEX];
            case (? #leaf(leaf)) Debug.trap("Branch.get_child(): Expected a branch, got a leaf");
            case (_) {};
        };

        MemoryRegion.loadNat16(btree.metadata, branch_address + MC.INDEX_START) |> Nat16.toNat(_);
    };

    public func get_parent(btree : MemoryBTree, branch_address : Nat) : ?Nat {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) return branch.1 [AC.PARENT];
            case (? #leaf(leaf)) Debug.trap("Branch.get_child(): Expected a branch, got a leaf");
            case (_) {};
        };

        let parent = MemoryRegion.loadNat64(btree.metadata, branch_address + MC.PARENT_START);
        if (parent == MC.NULL_ADDRESS) null else ?Nat64.toNat(parent);
    };

    public func get_keys(btree : MemoryBTree, branch_address : Nat) : [var ?(MemoryBlock, Blob)] {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) return branch.2;
            case (? #leaf(leaf)) return leaf.2;
            case (_) {};
        };

        let keys = Array.init<?(MemoryBlock, Blob)>(btree.order - 1, null);
        read_keys_into(btree, branch_address, keys);
        keys;
    };

    public func get_key(btree : MemoryBTree, branch_address : Nat, i : Nat) : ?(MemoryBlock, Blob) {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) return branch.2 [i];
            case (? #leaf(leaf)) Debug.trap("Branch.get_child(): Expected a branch, got a leaf");
            case (_) {};
        };

        let key_offset = get_key_offset(branch_address, i);
        let key_address = MemoryRegion.loadNat64(btree.metadata, key_offset);
        let key_size = MemoryRegion.loadNat16(btree.metadata, key_offset + MC.ADDRESS_SIZE) |> Nat16.toNat(_);

        if (key_address == MC.NULL_ADDRESS) return null;

        let key_block = (Nat64.toNat(key_address), key_size);
        let key_blob = MemoryBlock.get_key(btree, key_block);
        ?(key_block, key_blob);
    };

    public func get_child(btree : MemoryBTree, branch_address : Nat, i : Nat) : ?Nat {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) return branch.3 [i];
            case (? #leaf(leaf)) Debug.trap("Branch.get_child(): Expected a branch, got a leaf");
            case (_) {};
        };

        MemoryRegion.loadNat64(btree.metadata, get_child_offset(btree, branch_address, i))
        |> ?Nat64.toNat(_);
    };

    public func get_subtree_size(btree : MemoryBTree, branch_address : Nat) : Nat {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) return branch.0 [AC.SUBTREE_SIZE];
            case (? #leaf(leaf)) Debug.trap("Branch.get_child(): Expected a branch, got a leaf");
            case (_) {};
        };

        MemoryRegion.loadNat32(btree.metadata, branch_address + MC.SUBTREE_COUNT_START) |> Nat32.toNat(_);
    };

    public func binary_search<K, V>(btree: MemoryBTree, mem_utils: MemoryUtils<K, V>, address: Nat, cmp : (K, K) -> Int8, search_key : K, arr_len : Nat) : Int {
        if (arr_len == 0) return -1; // should insert at index Int.abs(i + 1)
        var l = 0;

        // arr_len will always be between 4 and 512
        var r = arr_len - 1 : Nat;

        while (l < r) {
            let mid = (l + r) / 2;

            let ?composite_key = get_key(btree, address, mid) else Debug.trap("1. binary_search_blob_seq: accessed a null value");

            let key_blob = composite_key.1;
            let key = mem_utils.0.from_blob(key_blob);

            let result = cmp(search_key, key);

            if (result == -1) {
                r := mid;

            } else if (result == 1) {
                l := mid + 1;
            } else {
                return mid;
            };
        };

        let insertion = l;

        // Check if the insertion point is valid
        // return the insertion point but negative and subtracting 1 indicating that the key was not found
        // such that the insertion index for the key is Int.abs(insertion) - 1
        // [0,  1,  2]
        //  |   |   |
        // -1, -2, -3
        switch (get_key(btree, address, insertion)) {
            case (?(_, key_blob)) {
                let key = mem_utils.0.from_blob(key_blob);
                let result = cmp(search_key, key);

                if (result == 0) insertion
                else if (result == -1) -(insertion + 1)
                else  -(insertion + 2);
            };
            case (_) {
                Debug.print("insertion = " # debug_show insertion);
                Debug.print("arr_len = " # debug_show arr_len);
                Debug.print(
                    "arr = " # debug_show Array.freeze(get_keys(btree, address))
                );
                Debug.trap("2. binary_search_blob_seq: accessed a null value");
            };
        };
    };

    public func binary_search_blob_seq(btree: MemoryBTree, address : Nat, cmp : (Blob, Blob) -> Int8, search_key : Blob, arr_len : Nat) : Int {
        if (arr_len == 0) return -1; // should insert at index Int.abs(i + 1)
        var l = 0;

        // arr_len will always be between 4 and 512
        var r = arr_len - 1 : Nat;

        while (l < r) {
            let mid = (l + r) / 2;

            let ?key = get_key(btree, address, mid) else Debug.trap("1. binary_search_blob_seq: accessed a null value");

            let key_blob = key.1;
            let result = cmp(search_key, key_blob);

            if (result == -1) {
                r := mid;

            } else if (result == 1) {
                l := mid + 1;
            } else {
                return mid;
            };
        };

        let insertion = l;

        // Check if the insertion point is valid
        // return the insertion point but negative and subtracting 1 indicating that the key was not found
        // such that the insertion index for the key is Int.abs(insertion) - 1
        // [0,  1,  2]
        //  |   |   |
        // -1, -2, -3
        switch (get_key(btree, address,insertion)) {
            case (?(_, key_blob)) {
                let result = cmp(search_key, key_blob);

                if (result == 0) insertion
                else if (result == -1) -(insertion + 1)
                else  -(insertion + 2);
            };
            case (_) {
                Debug.print("insertion = " # debug_show insertion);
                Debug.print("arr_len = " # debug_show arr_len);
                Debug.print(
                    "arr = " # debug_show Array.freeze(get_keys(btree, address))
                );
                Debug.trap("2. binary_search_blob_seq: accessed a null value");
            };
        };
    };

    public func partial_update_count(btree : MemoryBTree, branch_address : Nat, count : Nat) {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) branch.0 [AC.COUNT] := count;
            case (? #leaf(_)) Debug.trap("Branch.partial_update_count(): Expected a branch, got a leaf");
            case (_) {};
        };

        MemoryRegion.storeNat16(btree.metadata, branch_address + MC.COUNT_START, Nat16.fromNat(count));
    };

    public func partial_update_subtree_size(btree : MemoryBTree, branch_address : Nat, new_size : Nat) {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) branch.0 [AC.SUBTREE_SIZE] := new_size;
            case (? #leaf(_)) Debug.trap("Branch.partial_update_subtree_size(): Expected a branch, got a leaf");
            case (_) {};
        };

        MemoryRegion.storeNat32(btree.metadata, branch_address + MC.SUBTREE_COUNT_START, Nat32.fromNat(new_size));
    };

    public func partial_update_parent(btree : MemoryBTree, branch_address : Nat, opt_parent : ?Nat) {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) branch.1 [AC.PARENT] := opt_parent;
            case (? #leaf(_)) Debug.trap("Branch.partial_update_parent(): Expected a branch, got a leaf");
            case (_) {};
        };

        let parent = switch (opt_parent) {
            case (null) MC.NULL_ADDRESS;
            case (?_parent) Nat64.fromNat(_parent);
        };

        MemoryRegion.storeNat64(btree.metadata, branch_address + MC.PARENT_START, parent);
    };

    public func update_median_key(btree : MemoryBTree, parent_branch : Branch, child_index : Nat, new_key : (MemoryBlock, Blob)) {
        var curr = parent_branch;
        var i = child_index;

        while (i == 0) {
            i := curr.0 [AC.INDEX];
            let ?parent_address = curr.1 [AC.PARENT] else return; // occurs when key is the first key in the tree
            curr := Branch.from_address(btree, parent_address, false);
        };

        Branch.put_key(btree, curr, i - 1, new_key);
    };

    // inserts node but does not update the subtree size with the node's subtree size
    // because it's likely that the inserted node is a node split from a node
    // in this branch's subtree
    public func partial_insert(btree : MemoryBTree, branch_address : Nat, i : Nat, key : (MemoryBlock, Blob), child_address : Nat) {
        let count = Branch.get_count(btree, branch_address);

        assert count < btree.order;
        assert i <= count;

        let key_block = key.0;

        switch(LruCache.peek(btree.nodes_cache, nhash, branch_address)){
            case (?#branch(branch)) {
                var j = count;

                while (j > i) {
                    branch.2 [j - 1] := branch.2 [j - 2];
                    branch.3 [j] := branch.3 [j - 1];

                    j -= 1;
                };

                branch.2 [i - 1] := ?key;
                branch.3 [i] := ?child_address;

            };
            case (?#leaf(_)) Debug.trap("Branch.partial_insert(): Expected a branch, got a leaf");
            case (_) {};
        };


        // shift keys and children
        do {
             if (i == 0) {
                // elements inserted are always nodes created as a result of split
                // so their index is always greater than one as new nodes created from
                // a split operation are always inserted at the right
                // update_median_key(btree, branch, i, key);
            } else {
                let key_offset = get_key_offset(branch_address, i - 1);
                let key_end_boundary = get_key_offset(branch_address, count - 1);

                MemoryFns.shift(btree.metadata, key_offset, key_end_boundary, MC.MAX_KEY_SIZE + MC.ADDRESS_SIZE);
                MemoryRegion.storeNat64(btree.metadata, key_offset, Nat64.fromNat(key_block.0));
                MemoryRegion.storeNat16(btree.metadata, key_offset + MC.ADDRESS_SIZE, Nat16.fromNat(key_block.1));
            };

            let child_offset = get_child_offset(btree, branch_address, i);
            let child_end_boundary = get_child_offset(btree, branch_address, count);

            MemoryFns.shift(btree.metadata, child_offset, child_end_boundary, MC.ADDRESS_SIZE);
            MemoryRegion.storeNat64(btree.metadata, child_offset, Nat64.fromNat(child_address));
        };
       
       // update children index values
        var j = count;

        while (j >= i) {
            // if (j == i) {
            //     branch.2 [j - 1] := ?key;
            //     let #leaf(node) or #branch(node) = child;
            //     branch.3 [j] := ?node.0 [AC.ADDRESS];
            // } else {
            //     branch.2 [j - 1] := branch.2 [j - 2];
            //     branch.3 [j] := branch.3 [j - 1];
            // };

            let ?child_address = Branch.get_child(btree, branch_address, j) else Debug.trap("Branch.insert(): child address is null");

            switch (Branch.get_node_type(btree, child_address)) {
                case ((#branch)) {
                    Branch.partial_update_index(btree, child_address, j);
                };
                case (#leaf) {
                    Leaf.partial_update_index(btree, child_address, j);
                };
            };

            j -= 1;
        };

        Branch.partial_update_count(btree, branch_address, count + 1);

    };

    public func insert(btree : MemoryBTree, branch : Branch, i : Nat, key : (MemoryBlock, Blob), child : Node) {

        var j = branch.0 [AC.COUNT];
        assert j < btree.order;
        assert i <= branch.0 [AC.COUNT];

        let key_block = key.0;
        while (j >= i) {
            if (j == i) {
                branch.2 [j - 1] := ?key;
                let #leaf(node) or #branch(node) = child;
                branch.3 [j] := ?node.0 [AC.ADDRESS];
            } else {
                branch.2 [j - 1] := branch.2 [j - 2];
                branch.3 [j] := branch.3 [j - 1];
            };

            let ?child_address = branch.3 [j] else Debug.trap("Branch.insert(): child address is null");

            switch (Branch.get_node_type(btree, child_address)) {
                case ((#branch)) {
                    Branch.partial_update_index(btree, child_address, j);
                };
                case (#leaf) {
                    Leaf.partial_update_index(btree, child_address, j);
                };
            };

            j -= 1;
        };

        if (i == 0) {
            // elements inserted are always nodes created as a result of split
            // so their index is always greater than one as new nodes created from
            // a split operation are always inserted at the right
            // update_median_key(btree, branch, i, key);
        } else {
            let key_offset = get_key_offset(branch.0 [AC.ADDRESS], i - 1);
            let key_end_boundary = get_key_offset(branch.0 [AC.ADDRESS], branch.0 [AC.COUNT] - 1);

            MemoryFns.shift(btree.metadata, key_offset, key_end_boundary, MC.MAX_KEY_SIZE + MC.ADDRESS_SIZE);
            MemoryRegion.storeNat64(btree.metadata, key_offset, Nat64.fromNat(key_block.0));
            MemoryRegion.storeNat16(btree.metadata, key_offset + MC.ADDRESS_SIZE, Nat16.fromNat(key_block.1));
        };

        let child_address = switch (child) {
            case (#branch(child_node)) child_node.0 [AC.ADDRESS];
            case (#leaf(child_node)) child_node.0 [AC.ADDRESS];
        };

        let child_offset = get_child_offset(btree, branch.0 [AC.ADDRESS], i);
        let child_end_boundary = get_child_offset(btree, branch.0 [AC.ADDRESS], branch.0 [AC.COUNT]);

        MemoryFns.shift(btree.metadata, child_offset, child_end_boundary, MC.ADDRESS_SIZE);
        MemoryRegion.storeNat64(btree.metadata, child_offset, Nat64.fromNat(child_address));

        Branch.update_count(btree, branch, branch.0 [AC.COUNT] + 1);

    };

    public func partial_split(btree : MemoryBTree, branch_address : Nat, child_index : Nat, first_child_key : (MemoryBlock, Blob), child : Nat) : Nat {
        
        let arr_len = btree.order;
        let median = (arr_len / 2) + 1;

        let is_elem_added_to_right = child_index >= median;

        var median_key = ?first_child_key;

        var offset = if (is_elem_added_to_right) 0 else 1;
        var already_inserted = false;

        let right_cnt = arr_len + 1 - median : Nat;
        let right_address = Branch.partial_new(btree);
        
        var i = 0;
        var elems_removed_from_left = 0;

        while (i < right_cnt) {
            let j = i + median - offset : Nat;

            let child_node = if (j >= median and j == child_index and not already_inserted) {
                offset += 1;
                already_inserted := true;
                if (i > 0) Branch.partial_put_key(btree, right_address, i - 1, first_child_key);
                child;
            } else {
                if (i == 0) {
                    median_key := Branch.get_key(btree, branch_address, j - 1);
                } else {
                    let ?shifted_key = Branch.get_key(btree, branch_address, j - 1) else Debug.trap("Branch.split: accessed a null value");
                    Branch.partial_put_key(btree, right_address, i - 1, shifted_key);
                };

                // branch.2 [j - 1] := null;
                // branch.0 [AC.COUNT] -= 1;

                elems_removed_from_left += 1;

                let ?child_address = Branch.get_child(btree, branch_address, j) else Debug.trap("Branch.split: accessed a null value");
                child_address;
            };

            Branch.partial_add_child(btree, right_address, child_node);
            i += 1;
        };

        // remove the elements moved to the right branch from the subtree size of the left branch
        let prev_left_subtree_size = Branch.get_subtree_size(btree, branch_address);
        let right_subtree_size = Branch.get_subtree_size(btree, right_address);
        Branch.partial_update_subtree_size(btree, branch_address, prev_left_subtree_size - right_subtree_size);
 
        // update the count of the left branch
        // to reflect the removed elements
        let prev_left_count = Branch.get_count(btree, branch_address);
        Branch.partial_update_count(btree, branch_address, prev_left_count - elems_removed_from_left);

        if (not is_elem_added_to_right) {
            Branch.partial_insert(btree, branch_address, child_index, first_child_key, child);
        };

        Branch.partial_update_count(btree, branch_address, median);

        let branch_index = Branch.get_index(btree, branch_address);
        Branch.partial_update_index(btree, right_address, branch_index + 1);

        Branch.partial_update_count(btree, right_address, right_cnt);

        let branch_parent = Branch.get_parent(btree, branch_address);
        Branch.partial_update_parent(btree, right_address, branch_parent);

        // store the first key of the right node at the end of the keys in left node
        // no need to delete as the value will get overwritten because it exceeds the count position
        let ?_median_key = median_key else Debug.trap("Branch.split: median key is null");
        Branch.partial_put_key(btree, right_address, btree.order - 2, _median_key);

        right_address;
    };
};
