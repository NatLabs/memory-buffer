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

module Branch {

    type Address = Nat;
    type MemoryRegion = MemoryRegion.MemoryRegion;
    type LruCache<K, V> = LruCache.LruCache<K, V>;
    type Blobify<A> = Blobify.Blobify<A>;
    type RevIter<A> = RevIter.RevIter<A>;
    type MemoryBTree = T.MemoryBTree;

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

    public func update_count(btree : MemoryBTree, branch : Branch, new_count : Nat) {
        MemoryRegion.storeNat16(btree.metadata, branch.0 [AC.ADDRESS] + MC.COUNT_START, Nat16.fromNat(new_count));
        branch.0 [AC.COUNT] := new_count;
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

    public func add_child(btree : MemoryBTree, branch : Branch, child : Nat) {
        let count = branch.0 [AC.COUNT];
        assert count < btree.order;

        branch.3 [count] := ?child;

        let offset = branch.0 [AC.ADDRESS] + CHILDREN_START(btree) + (count * MC.ADDRESS_SIZE);
        MemoryRegion.storeNat64(btree.metadata, offset, Nat64.fromNat(child));

        update_count(btree, branch, count + 1);
    };
};
