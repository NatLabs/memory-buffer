import Itertools "mo:itertools/Iter";
import RevIter "mo:itertools/RevIter";

import Migrations "migrations";
import MemoryBTree "Base";
import T "modules/Types";

module VersionedMemoryBTree {
    public type MemoryBTree = Migrations.MemoryBTree;
    public type VersionedMemoryBTree = Migrations.VersionedMemoryBTree;
    public type MemoryBlock = T.MemoryBlock;
    public type MemoryUtils<K, V> = T.MemoryUtils<K, V>;
    type RevIter<A> = RevIter.RevIter<A>;

    public func new(order : ?Nat, cache_size : ?Nat) : VersionedMemoryBTree {
        let btree = MemoryBTree.new(order, cache_size);
        MemoryBTree.toVersioned(btree);
    };

    public func size(btree : VersionedMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.size(state);
    };

    public func insert<K, V>(
        btree : VersionedMemoryBTree,
        mem_utils : MemoryUtils<K, V>,
        key : K,
        val : V,
    ) : ?V {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.insert(btree, mem_utils, key, val);
    };

    public func entries<K, V>(btree: MemoryBTree, mem_utils: MemoryUtils<K, V>) : RevIter<(K, V)> {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.entries(btree, mem_utils, key, val);
    };

    public func keys<K, V>(btree: MemoryBTree, mem_utils: MemoryUtils<K, V>) : RevIter<K> {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.keys(btree, mem_utils, key, val);
    };

    public func remove<K, V>(
        btree : VersionedMemoryBTree,
        mem_utils : MemoryUtils<K, V>,
        key : K,
    ) : ?V {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.remove(btree, mem_utils, key);
    };

    public func get<K, V>(
        btree : VersionedMemoryBTree,
        mem_utils : MemoryUtils<K, V>,
        key : K,
    ) : ?V {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.get(btree, mem_utils, key);
    };

    public func clear(btree : VersionedMemoryBTree) {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.clear(btree);
    };

    public func fromArray<K, V>(
        btree : VersionedMemoryBTree,
        mem_utils : MemoryUtils<K, V>,
        arr : [(K, V)],
    ) {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.fromArray(btree, mem_utils, arr);
    };
    
};
