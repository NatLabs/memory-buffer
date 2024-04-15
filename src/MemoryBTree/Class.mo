import Itertools "mo:itertools/Iter";
import RevIter "mo:itertools/RevIter";

import Migrations "migrations";
import MemoryBTree "Base";
import VersionedMemoryBTree "Versioned";
import T "modules/Types";
import Versioned "Versioned";

module {
    public type MemoryBTree = Migrations.MemoryBTree;
    public type VersionedMemoryBTree = Migrations.VersionedMemoryBTree;
    public type MemoryBlock = T.MemoryBlock;
    public type MemoryUtils<K, V> = T.MemoryUtils<K, V>;
    type RevIter<A> = RevIter.RevIter<A>;

    public func new(order: ?Nat, cache_size:?Nat) : VersionedMemoryBTree = VersionedMemoryBTree.new(order, cache_size);
    public func newStableStore(order: ?Nat, cache_size:?Nat) : VersionedMemoryBTree = VersionedMemoryBTree.new(order, cache_size);

    public func upgrade<K, V>(versions: VersionedMemoryBTree<K, V>) : VersionedMemoryBTree<K, V> {
        Migrations.upgrade(versions);
    };

    public class MemoryBTreeClass<K, V>(versions: VersionedMemoryBTree, mem_utils: MemoryUtils<K, V>){
        let state = Migrations.getCurrentVersion(versions);

        public func get(key: K) : ?V = MemoryBTree.get<K, V>(state, key, mem_utils);
        public func getMax() : ?(K, V) = MemoryBTree.getMax<K, V>(state, mem_utils);
        public func getMin() : ?(K, V) = MemoryBTree.getMin<K, V>(state, mem_utils);
        public func getCeiling(key: K) : ?(K, V) = MemoryBTree.getCeiling<K, V>(state, mem_utils, key);
        public func getFloor(key: K) : ?(K, V) = MemoryBTree.getFloor<K, V>(state, mem_utils, key);
        public func getFromIndex(i: Nat) : (K, V) = MemoryBTree.getFromIndex<K, V>(state, mem_utils, i);
        public func getIndex(key: K) : Nat = MemoryBTree.getIndex<K, V>(state, key, mem_utils);

        public func insert(key: K, val: V) : ?V = MemoryBTree.insert<K, V>(state, mem_utils, key, val);
        public func remove(key: K) : ?V = MemoryBTree.remove<K, V>(state, mem_utils, key);
        public func removeMax() : ?(K, V) = MemoryBTree.removeMax<K, V>(state, mem_utils);
        public func removeMin() : ?(K, V) = MemoryBTree.removeMin<K, V>(state, mem_utils);

        public func clear() = MemoryBTree.clear(state, mem_utils);
        public func entries() : RevIter<(K, V)> = MemoryBTree.entries(state, mem_utils);
        public func keys() : RevIter<(K)> = MemoryBTree.keys(state, mem_utils);
        public func vals()  : RevIter<(V)> = MemoryBTree.vals(state, mem_utils);
        public func range(i: Nat, j: Nat) : RevIter<(K, V)> = MemoryBTree.range(state, mem_utils, i, j);
        public func scan(start: ?K, end: ?K) : RevIter<(K, V)> = MemoryBTree.scan(state, mem_utils, start, end);

        public func size() : Nat = MemoryBTree.size(state);

    };
}