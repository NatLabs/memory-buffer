# MemoryBTree/Versioned

## Type `MemoryBTree`
``` motoko no-repl
type MemoryBTree = Migrations.MemoryBTree
```


## Type `VersionedMemoryBTree`
``` motoko no-repl
type VersionedMemoryBTree = Migrations.VersionedMemoryBTree
```


## Type `MemoryBlock`
``` motoko no-repl
type MemoryBlock = T.MemoryBlock
```


## Type `BTreeUtils`
``` motoko no-repl
type BTreeUtils<K, V> = T.BTreeUtils<K, V>
```


## Function `new`
``` motoko no-repl
func new(order : ?Nat) : VersionedMemoryBTree
```


## Function `fromArray`
``` motoko no-repl
func fromArray<K, V>(btree_utils : BTreeUtils<K, V>, arr : [(K, V)], order : ?Nat) : VersionedMemoryBTree
```


## Function `toArray`
``` motoko no-repl
func toArray<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>) : [(K, V)]
```


## Function `insert`
``` motoko no-repl
func insert<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>, key : K, val : V) : ?V
```


## Function `remove`
``` motoko no-repl
func remove<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ?V
```


## Function `removeMax`
``` motoko no-repl
func removeMax<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>) : ?(K, V)
```


## Function `removeMin`
``` motoko no-repl
func removeMin<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>) : ?(K, V)
```


## Function `get`
``` motoko no-repl
func get<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ?V
```


## Function `getMax`
``` motoko no-repl
func getMax<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>) : ?(K, V)
```


## Function `getMin`
``` motoko no-repl
func getMin<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>) : ?(K, V)
```


## Function `getCeiling`
``` motoko no-repl
func getCeiling<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ?(K, V)
```


## Function `getFloor`
``` motoko no-repl
func getFloor<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ?(K, V)
```


## Function `getFromIndex`
``` motoko no-repl
func getFromIndex<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>, index : Nat) : (K, V)
```


## Function `getIndex`
``` motoko no-repl
func getIndex<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : Nat
```


## Function `clear`
``` motoko no-repl
func clear(btree : VersionedMemoryBTree)
```


## Function `entries`
``` motoko no-repl
func entries<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<(K, V)>
```


## Function `keys`
``` motoko no-repl
func keys<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<K>
```


## Function `vals`
``` motoko no-repl
func vals<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<V>
```


## Function `scan`
``` motoko no-repl
func scan<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>, start : ?K, end : ?K) : RevIter<(K, V)>
```


## Function `range`
``` motoko no-repl
func range<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>, start : Nat, end : Nat) : RevIter<(K, V)>
```


## Function `size`
``` motoko no-repl
func size(btree : VersionedMemoryBTree) : Nat
```


## Function `bytes`
``` motoko no-repl
func bytes(btree : VersionedMemoryBTree) : Nat
```


## Function `metadataBytes`
``` motoko no-repl
func metadataBytes(btree : VersionedMemoryBTree) : Nat
```


## Function `getId`
``` motoko no-repl
func getId<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ?Nat
```


## Function `nextId`
``` motoko no-repl
func nextId<K, V>(btree : VersionedMemoryBTree) : Nat
```


## Function `lookup`
``` motoko no-repl
func lookup<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>, id : Nat) : ?(K, V)
```


## Function `lookupKey`
``` motoko no-repl
func lookupKey<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>, id : Nat) : ?K
```


## Function `lookupVal`
``` motoko no-repl
func lookupVal<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>, id : Nat) : ?V
```


## Function `reference`
``` motoko no-repl
func reference<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>, id : Nat)
```


## Function `getRefCount`
``` motoko no-repl
func getRefCount<K, V>(btree : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>, id : Nat) : ?Nat
```

