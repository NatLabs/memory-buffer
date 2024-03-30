import Nat "mo:base/Nat";
import Blob "mo:base/Blob";

import MemoryRegion "mo:memory-region/MemoryRegion";
import LruCache "mo:lru-cache";
import BTree "mo:stableheapbtreemap/BTree";
import RevIter "mo:itertools/RevIter";

import MemoryCmp "../MemoryCmp";
import T "Types";

module MemoryBlock {

    type Address = Nat;
    type MemoryRegion = MemoryRegion.MemoryRegion;
    type LruCache<K, V> = LruCache.LruCache<K, V>;
    type RevIter<A> = RevIter.RevIter<A>;

    public type MemoryCmp<A> = MemoryCmp.MemoryCmp<A>;

    public type MemoryBTree = T.MemoryBTree;
    public type Node = T.Node;
    public type MemoryBlock = T.MemoryBlock;
    public type MemoryUtils<K, V> = T.MemoryUtils<K, V>;


    public func store_kv(btree : MemoryBTree, key : Blob, value : Blob) : MemoryBlock {
        let mb_address = MemoryRegion.allocate(btree.blobs, key.size() + value.size());
        MemoryRegion.storeBlob(btree.blobs, mb_address, key);
        MemoryRegion.storeBlob(btree.blobs, mb_address + key.size(), value);

        (mb_address, key.size(), value.size());
    };

    public func replace_kv(btree : MemoryBTree, prev_block : MemoryBlock, key : Blob, value : Blob) : (Nat, Nat, Nat) {
        let new_mb_address = MemoryRegion.resize(btree.blobs, prev_block.0, prev_block.1 + prev_block.2, key.size() + value.size());
        MemoryRegion.storeBlob(btree.blobs, new_mb_address, key);
        MemoryRegion.storeBlob(btree.blobs, new_mb_address + key.size(), value);

        (new_mb_address, key.size(), value.size());
    };

    public func get_key(btree : MemoryBTree, mb : MemoryBlock) : Blob {
        MemoryRegion.loadBlob(btree.blobs, mb.0, mb.1);
    };

    public func get_key_alt(btree : MemoryBTree, addr : Nat, size:Nat) : Blob {
        MemoryRegion.loadBlob(btree.blobs, addr, size);
    };

    public func get_value(btree : MemoryBTree, mb : MemoryBlock) : Blob {
        MemoryRegion.loadBlob(btree.blobs, mb.0 + mb.1, mb.2);
    };
};
