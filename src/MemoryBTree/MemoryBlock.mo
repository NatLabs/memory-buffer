import Nat "mo:base/Nat";
import Blob "mo:base/Blob";

import MemoryRegion "mo:memory-region/MemoryRegion";
import LruCache "mo:lru-cache";
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

    let {nhash} = LruCache;

    public func store_key(btree : MemoryBTree, key : Blob) : MemoryBlock {
        let mb_address = MemoryRegion.allocate(btree.blobs, key.size());
        MemoryRegion.storeBlob(btree.blobs, mb_address, key);

        // LruCache.put(btree.keys_cache, nhash, mb_address, key);

        (mb_address, key.size());
    };

    public func store_val(btree : MemoryBTree, val : Blob) : MemoryBlock {
        let mb_address = MemoryRegion.allocate(btree.blobs, val.size());
        MemoryRegion.storeBlob(btree.blobs, mb_address, val);

        // LruCache.put(btree.vals_cache, nhash, mb_address, val);

        (mb_address, val.size());
    };

    public func replace_val(btree : MemoryBTree, prev_block : MemoryBlock, val : Blob) : MemoryBlock {
        let new_mb_address = MemoryRegion.resize(btree.blobs, prev_block.0, prev_block.1, val.size());
        MemoryRegion.storeBlob(btree.blobs, new_mb_address, val);

        // ignore LruCache.remove(btree.vals_cache, nhash, prev_block.0);

        // LruCache.put(btree.vals_cache, nhash, new_mb_address, val);

        (new_mb_address, val.size());
    };

    public func get_key(btree : MemoryBTree, mb : MemoryBlock) : Blob {
        let blob = MemoryRegion.loadBlob(btree.blobs, mb.0, mb.1);
        // LruCache.put(btree.keys_cache, nhash, mb.0, blob);
        blob;
    };

    public func get_val(btree : MemoryBTree, mb : MemoryBlock) : Blob {
        let blob = MemoryRegion.loadBlob(btree.blobs, mb.0, mb.1);
        // LruCache.put(btree.vals_cache, nhash, mb.0, blob);
        blob;
    };

    public func remove_val(btree : MemoryBTree, mb : MemoryBlock) {
        MemoryRegion.deallocate(btree.blobs, mb.0, mb.1);
    };

    public func remove_key(btree : MemoryBTree, mb : MemoryBlock) {
        MemoryRegion.deallocate(btree.blobs, mb.0, mb.1);
    };
};
