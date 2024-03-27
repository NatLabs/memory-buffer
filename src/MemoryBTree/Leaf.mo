import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";

import MemoryRegion "mo:memory-region/MemoryRegion";
import LruCache "mo:lru-cache";
import BTree "mo:stableheapbtreemap/BTree";
import RevIter "mo:itertools/RevIter";
// import Branch "mo:augmented-btrees/BpTree/Branch";

import MemoryFns "./MemoryFns";
import Blobify "../Blobify";
import MemoryCmp "../MemoryCmp";
import ArrayMut "ArrayMut";
import MemoryBTree "..";
import T "Types";

module Leaf {
    public type Leaf = T.Leaf;
    type MemoryBTree = T.MemoryBTree;
    type MemoryBlock = T.MemoryBlock;

    let { nhash } = LruCache;

    public let FLAG_START = 0;
    public let FLAG_SIZE = 1;

    public let PARENT_START = 1;
    public let ADDRESS_SIZE = 8;

    public let INDEX_START = 9;
    public let INDEX_SIZE = 2;

    public let PREV_START = 11;

    public let NEXT_START = 19;

    public let COUNT_START = 27;
    public let COUNT_SIZE = 2;

    public let KV_START = 29;
    public let MAX_KEY_SIZE = 2;
    public let MAX_VALUE_SIZE = 4;

    // access constants
    public let AC = {
        ADDRESS = 0;
        INDEX = 1;
        COUNT = 2;

        PARENT = 0;
        PREV = 1;
        NEXT = 2;
    };

    public let Flags = {
        IS_LEAF_MASK : Nat8 = 0x80;
        IS_ROOT_MASK : Nat8 = 0x40; // DOUBLES AS HAS_PARENT_MASK
        HAS_PREV_MASK : Nat8 = 0x20;
        HAS_NEXT_MASK : Nat8 = 0x10;
    };

    public let KV_MEMORY_BLOCK_SIZE = 14; // ADDRESS_SIZE + MAX_KEY_SIZE + MAX_VALUE_SIZE

    public func get_memory_size(btree : MemoryBTree) : Nat {
        let bytes_per_node = FLAG_SIZE // flags
        + ADDRESS_SIZE // parent address
        + INDEX_SIZE // Node's position in parent node
        + ADDRESS_SIZE // prev leaf address
        + ADDRESS_SIZE // next leaf address
        + COUNT_SIZE // number of elements in the node
        // key value pairs
        + (
            (
                ADDRESS_SIZE // address of memory block
                + MAX_KEY_SIZE // key size
                + MAX_VALUE_SIZE // value size
            ) * btree.order
        );

        bytes_per_node;
    };

    public func new(btree : MemoryBTree) : Leaf {
        let bytes_per_node = Leaf.get_memory_size(btree);

        let leaf_address = MemoryRegion.allocate(btree.metadata, bytes_per_node);

        let leaf : Leaf = (
            [var leaf_address, 0, 0],
            [var null, null, null],
            Array.init<?MemoryBlock>(btree.order, null),
        );

        let flag : Nat8 = Flags.IS_LEAF_MASK;
        MemoryRegion.storeNat8(btree.metadata, leaf_address, flag); // flags
        // skip parent
        MemoryRegion.storeNat16(btree.metadata, leaf_address + 9, 0); // Node's position in parent node
        // skip prev leaf address
        // skip next leaf address
        MemoryRegion.storeNat16(btree.metadata, leaf_address + 21, 0); // number of elements in the node

        LruCache.put(btree.nodes_cache, nhash, leaf.0 [AC.ADDRESS], #leaf(leaf));

        leaf;
    };

    public func from_memory(btree : MemoryBTree, address : Nat) : Leaf {
        let flag = MemoryRegion.loadNat8(btree.metadata, address);
        assert (flag & Flags.IS_LEAF_MASK) == Flags.IS_LEAF_MASK;

        let is_root = (flag & Flags.IS_ROOT_MASK) == Flags.IS_ROOT_MASK;
        let has_prev = (flag & Flags.HAS_PREV_MASK) == Flags.HAS_PREV_MASK;
        let has_next = (flag & Flags.HAS_NEXT_MASK) == Flags.HAS_NEXT_MASK;

        let index = MemoryRegion.loadNat16(btree.metadata, address + INDEX_START) |> Nat16.toNat(_);
        let count = MemoryRegion.loadNat16(btree.metadata, address + COUNT_START) |> Nat16.toNat(_);

        let leaf : Leaf = (
            [var address, index, count],
            [var null, null, null],
            Array.init<?MemoryBlock>(btree.order, null),
        );

        leaf.1 [AC.PARENT] := if (is_root) null else {
            MemoryRegion.loadNat64(btree.metadata, address + PARENT_START)
            |> ?Nat64.toNat(_);
        };

        leaf.1 [AC.PREV] := if (has_prev) {
            MemoryRegion.loadNat64(btree.metadata, address + PREV_START)
            |> ?Nat64.toNat(_);
        } else null;

        leaf.1 [AC.NEXT] := if (has_next) {
            MemoryRegion.loadNat64(btree.metadata, address + NEXT_START)
            |> ?Nat64.toNat(_);
        } else null;

        var i = 0;
        let kv_offset = address + KV_START;

        while (i < count) {
            let ptr = kv_offset + (i * (MAX_KEY_SIZE + MAX_VALUE_SIZE));

            let mb_address = MemoryRegion.loadNat64(btree.metadata, ptr) |> Nat64.toNat(_);
            let key_size = MemoryRegion.loadNat16(btree.metadata, ptr + ADDRESS_SIZE) |> Nat16.toNat(_);
            let value_size = MemoryRegion.loadNat32(btree.metadata, ptr + ADDRESS_SIZE + MAX_KEY_SIZE) |> Nat32.toNat(_);

            leaf.2 [i] := ?(mb_address, key_size, value_size);
        };

        leaf;
    };

    public func is_leaf(btree : MemoryBTree, leaf : Leaf) : Bool {
        let IS_LEAF_MASK : Nat8 = 0x80;

        let flag = MemoryRegion.loadNat8(btree.metadata, leaf.0 [AC.ADDRESS]);
        (flag & IS_LEAF_MASK) == IS_LEAF_MASK;
    };

    public func set_is_root(btree : MemoryBTree, leaf : Leaf, is_root : Bool) {
        let IS_ROOT_MASK : Nat8 = 0x40;
        let flag = MemoryRegion.loadNat8(btree.metadata, leaf.0 [AC.ADDRESS]);
        if (is_root) {
            MemoryRegion.storeNat8(btree.metadata, leaf.0 [AC.ADDRESS], flag | IS_ROOT_MASK);
        } else {
            MemoryRegion.storeNat8(btree.metadata, leaf.0 [AC.ADDRESS], flag & (^IS_ROOT_MASK));
        };
    };

    public func update_count(btree : MemoryBTree, leaf : Leaf, new_count : Nat) {
        MemoryRegion.storeNat16(btree.metadata, leaf.0 [AC.ADDRESS] + COUNT_START, Nat16.fromNat(new_count));
        leaf.0 [AC.COUNT] := new_count;
    };

    public func insert(btree : MemoryBTree, leaf : Leaf, index : Nat, mem_block : MemoryBlock) {
        assert index <= leaf.0 [AC.COUNT] and leaf.0 [AC.COUNT] < btree.order;

        var i = leaf.0 [AC.COUNT];
        while (i > index) {
            leaf.2 [i] := leaf.2 [i - 1];
            i -= 1;
        };

        leaf.2 [index] := ?mem_block;

        let start = leaf.0 [AC.ADDRESS] + KV_START + (index * KV_MEMORY_BLOCK_SIZE);
        let end = leaf.0 [AC.ADDRESS] + KV_START + (leaf.0 [AC.COUNT] * KV_MEMORY_BLOCK_SIZE);

        MemoryFns.shift(btree.metadata, start, end, KV_MEMORY_BLOCK_SIZE);
        MemoryRegion.storeNat64(btree.metadata, start, Nat64.fromNat(mem_block.0));
        MemoryRegion.storeNat16(btree.metadata, start + ADDRESS_SIZE, Nat16.fromNat(mem_block.1));
        MemoryRegion.storeNat32(btree.metadata, start + ADDRESS_SIZE + MAX_KEY_SIZE, Nat32.fromNat(mem_block.2));

        Leaf.update_count(btree, leaf, leaf.0 [AC.COUNT] + 1);
    };

    public func put(btree : MemoryBTree, leaf : Leaf, index : Nat, mem_block : MemoryBlock) {

        leaf.2 [index] := ?mem_block;

        let kv_offset = leaf.0 [AC.ADDRESS] + KV_START + (index * KV_MEMORY_BLOCK_SIZE);
        MemoryRegion.storeNat64(btree.metadata, kv_offset, Nat64.fromNat(mem_block.0));
        MemoryRegion.storeNat16(btree.metadata, kv_offset + ADDRESS_SIZE, Nat16.fromNat(mem_block.1));
        MemoryRegion.storeNat32(btree.metadata, kv_offset + ADDRESS_SIZE + MAX_KEY_SIZE, Nat32.fromNat(mem_block.2));

    };

    public func update_index(btree : MemoryBTree, leaf : Leaf, new_index : Nat) {
        MemoryRegion.storeNat16(btree.metadata, leaf.0 [AC.ADDRESS] + INDEX_START, Nat16.fromNat(new_index));
        leaf.0 [AC.INDEX] := new_index;
    };

    public func update_parent(btree : MemoryBTree, leaf : Leaf, parent : ?Nat) {
        switch (parent) {
            case (null) {
                leaf.1 [AC.PARENT] := null;
            };
            case (?_parent) {
                MemoryRegion.storeNat64(btree.metadata, leaf.0 [AC.ADDRESS] + PARENT_START, Nat64.fromNat(_parent));
                leaf.1 [AC.PARENT] := parent;
            };
        };
    };

    public func update_next(btree : MemoryBTree, leaf : Leaf, next : ?Nat) {
        switch (next) {
            case (null) {
                let flag = MemoryRegion.loadNat8(btree.metadata, leaf.0 [AC.ADDRESS]);
                MemoryRegion.storeNat8(btree.metadata, leaf.0 [AC.ADDRESS], flag & (^Flags.HAS_NEXT_MASK));
                leaf.1 [AC.NEXT] := null;
            };
            case (?_next) {
                let flag = MemoryRegion.loadNat8(btree.metadata, leaf.0 [AC.ADDRESS]);
                MemoryRegion.storeNat8(btree.metadata, leaf.0 [AC.ADDRESS], flag | Flags.HAS_NEXT_MASK);
                MemoryRegion.storeNat64(btree.metadata, leaf.0 [AC.ADDRESS] + NEXT_START, Nat64.fromNat(_next));
                leaf.1 [AC.NEXT] := next;
            };
        };
    };

    public func update_prev(btree : MemoryBTree, leaf : Leaf, prev : ?Nat) {
        switch (prev) {
            case (null) {
                let flag = MemoryRegion.loadNat8(btree.metadata, leaf.0 [AC.ADDRESS]);
                MemoryRegion.storeNat8(btree.metadata, leaf.0 [AC.ADDRESS], flag & (^Flags.HAS_PREV_MASK));
                leaf.1 [AC.PREV] := null;
            };
            case (?_prev) {
                let flag = MemoryRegion.loadNat8(btree.metadata, leaf.0 [AC.ADDRESS]);
                MemoryRegion.storeNat8(btree.metadata, leaf.0 [AC.ADDRESS], flag | Flags.HAS_PREV_MASK);
                MemoryRegion.storeNat64(btree.metadata, leaf.0 [AC.ADDRESS] + PREV_START, Nat64.fromNat(_prev));
                leaf.1 [AC.PREV] := prev;
            };
        };
    };

    public func split(btree : MemoryBTree, leaf : Leaf, elem_index : Nat, elem_mem_block : MemoryBlock) : Leaf {
        let arr_len = leaf.0 [AC.COUNT];
        let median = (arr_len / 2) + 1;

        let is_elem_added_to_right = elem_index >= median;

        var i = 0;
        let right_cnt = arr_len + 1 - median : Nat;
        let right_leaf = Leaf.new(btree);
        var already_inserted = false;
        var offset = if (is_elem_added_to_right) 0 else 1;

        while (i < right_cnt) {
            let j = i + median - offset : Nat;

            let ?mem_block = if (j >= median and j == elem_index and not already_inserted) {
                offset += 1;
                already_inserted := true;
                ?elem_mem_block;
            } else {
                ArrayMut.extract(leaf.2, j);
            } else Debug.trap("Leaf.split: mem_block is null");

            Leaf.put(btree, right_leaf, i, mem_block);

            i += 1;
        };

        Leaf.update_count(btree, leaf, median);
        Leaf.update_count(btree, right_leaf, right_cnt);

        if (not is_elem_added_to_right) {
            Leaf.insert(btree, leaf, elem_index, elem_mem_block);
        };

        Leaf.update_index(btree, right_leaf, leaf.0 [AC.INDEX] + 1);
        Leaf.update_parent(btree, right_leaf, leaf.1 [AC.PARENT]);

        // update leaf pointers
        Leaf.update_prev(btree, right_leaf, ?leaf.0 [AC.ADDRESS]);

        Leaf.update_next(btree, right_leaf, leaf.1 [AC.NEXT]);
        Leaf.update_next(btree, leaf, ?right_leaf.0 [AC.ADDRESS]);

        switch (right_leaf.1 [AC.NEXT]) {
            case (?next) {
                let next_leaf = Leaf.from_memory(btree, next) else Debug.trap("Leaf.split: next_leaf is not a leaf");
                Leaf.update_prev(btree, next_leaf, ?right_leaf.0 [AC.ADDRESS]);
            };
            case (_) {};
        };

        right_leaf;
    };

};
