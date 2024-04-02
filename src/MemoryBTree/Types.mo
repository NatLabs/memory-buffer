import Nat "mo:base/Nat";

import MemoryRegion "mo:memory-region/MemoryRegion";
import LruCache "mo:lru-cache";
import RevIter "mo:itertools/RevIter";
// import Branch "mo:augmented-btrees/BpTree/Branch";

import Blobify "../Blobify";
import MemoryCmp "../MemoryCmp";

module {
    public type Address = Nat;
    type Size = Nat;

    public type MemoryBlock = (Address, Size);

    type MemoryRegion = MemoryRegion.MemoryRegion;
    type LruCache<K, V> = LruCache.LruCache<K, V>;
    type Blobify<A> = Blobify.Blobify<A>;
    type RevIter<A> = RevIter.RevIter<A>;

    public type MemoryCmp<A> = MemoryCmp.MemoryCmp<A>;

    public type Leaf = (
        nats : [var Nat], // [address, index, count]
        adjacent_nodes : [var ?Nat], // [parent, prev, next] (is_root if parent is null)
        keys : [var ?(MemoryBlock, Blob)], // [... ((key address, key size), key blob)]
        vals : [var ?(MemoryBlock, Blob)]
    );

    public type Branch = (
        nats : [var Nat], // [address, index, count, subtree_size]
        parent : [var ?Nat], // parent
        keys : [var ?(MemoryBlock, Blob)], // [... ((key address, key size), key blob)]
        children_nodes : [var ?Nat], // [... child address]
    );

    public type MemoryUtils<K, V> = (
        key : Blobify<K>,
        value : Blobify<V>,
        cmp : MemoryCmp<K>,
    );

    public type Node = {
        #leaf : Leaf;
        #branch : Branch;
    };

    public type NodeType = {
        #branch;
        #leaf;
    };

    public type MemoryBTree = {
        is_set : Bool; // is true, only keys are stored
        order : Nat;
        var count : Nat;
        var root : Nat;
        var branch_count : Nat; // number of branch nodes
        var leaf_count : Nat; // number of leaf nodes

        metadata : MemoryRegion;
        blobs : MemoryRegion;

        nodes_cache : LruCache<Address, Node>;
        
    };


};
