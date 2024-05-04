# MemoryBTree/Base

## Type `MemoryCmp`
``` motoko no-repl
type MemoryCmp<A> = MemoryCmp.MemoryCmp<A>
```


## Type `MemoryBTree`
``` motoko no-repl
type MemoryBTree = Migrations.MemoryBTree
```


## Type `Node`
``` motoko no-repl
type Node = Migrations.Node
```


## Type `Leaf`
``` motoko no-repl
type Leaf = Migrations.Leaf
```


## Type `Branch`
``` motoko no-repl
type Branch = Migrations.Branch
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


## Function `_new_with_options`
``` motoko no-repl
func _new_with_options(order : ?Nat, opt_cache_size : ?Nat, is_set : Bool) : MemoryBTree
```


## Function `new_set`
``` motoko no-repl
func new_set(order : ?Nat, cache_size : ?Nat) : MemoryBTree
```


## Function `new`
``` motoko no-repl
func new(order : ?Nat) : MemoryBTree
```


## Value `BLOBS_REGION_HEADER_SIZE`
``` motoko no-repl
let BLOBS_REGION_HEADER_SIZE
```


## Value `METADATA_REGION_HEADER_SIZE`
``` motoko no-repl
let METADATA_REGION_HEADER_SIZE
```


## Value `POINTER_SIZE`
``` motoko no-repl
let POINTER_SIZE
```


## Value `LAYOUT_VERSION`
``` motoko no-repl
let LAYOUT_VERSION
```


## Value `Layout`
``` motoko no-repl
let Layout
```


## Function `size`
``` motoko no-repl
func size(btree : MemoryBTree) : Nat
```


## Function `fromVersioned`
``` motoko no-repl
func fromVersioned(btree : VersionedMemoryBTree) : MemoryBTree
```


## Function `toVersioned`
``` motoko no-repl
func toVersioned(btree : MemoryBTree) : VersionedMemoryBTree
```


## Function `bytes`
``` motoko no-repl
func bytes(btree : MemoryBTree) : Nat
```


## Function `metadataBytes`
``` motoko no-repl
func metadataBytes(btree : MemoryBTree) : Nat
```


## Function `insert`
``` motoko no-repl
func insert<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K, value : V) : ?V
```


## Function `reference`
``` motoko no-repl
func reference<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, id : UniqueId)
```

Increase the reference count of the entry with the given id if it exists.
The reference count is used to track the number of entities depending on the entry.
If the reference count is 0, the entry is deleted.
To decrease the reference count, use the `remove()` function.
This is an opt-in feature that helps you maintain the integrity of the data.
Prevents you from prematurely deleting an entry that is still being used.
If you don't need this feature, you can use the library without calling this function.

## Function `getRefCount`
``` motoko no-repl
func getRefCount<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, id : UniqueId) : ?Nat
```

Get the reference count of the entry with the given id.

## Function `lookup`
``` motoko no-repl
func lookup<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, id : UniqueId) : ?(K, V)
```


## Function `lookupKey`
``` motoko no-repl
func lookupKey<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, id : UniqueId) : ?K
```


## Function `lookupVal`
``` motoko no-repl
func lookupVal<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, id : UniqueId) : ?V
```


## Function `getId`
``` motoko no-repl
func getId<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ?UniqueId
```


## Function `nextId`
``` motoko no-repl
func nextId<K, V>(btree : MemoryBTree) : UniqueId
```


## Function `entries`
``` motoko no-repl
func entries<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<(K, V)>
```


## Function `toEntries`
``` motoko no-repl
func toEntries<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : [(K, V)]
```


## Function `toArray`
``` motoko no-repl
func toArray<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : [(K, V)]
```


## Function `keys`
``` motoko no-repl
func keys<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<K>
```


## Function `toKeys`
``` motoko no-repl
func toKeys<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : [K]
```


## Function `vals`
``` motoko no-repl
func vals<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<V>
```


## Function `toVals`
``` motoko no-repl
func toVals<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : [V]
```


## Function `leafNodes`
``` motoko no-repl
func leafNodes<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<[?(K, V)]>
```


## Function `toLeafNodes`
``` motoko no-repl
func toLeafNodes<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : [[?(K, V)]]
```


## Function `toNodeKeys`
``` motoko no-repl
func toNodeKeys<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : [[(Nat, [?K])]]
```


## Function `get`
``` motoko no-repl
func get<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ?V
```


## Function `getMin`
``` motoko no-repl
func getMin<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : ?(K, V)
```


## Function `getMax`
``` motoko no-repl
func getMax<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : ?(K, V)
```


## Function `clear`
``` motoko no-repl
func clear(btree : MemoryBTree)
```


## Function `remove`
``` motoko no-repl
func remove<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ?V
```


## Function `removeMin`
``` motoko no-repl
func removeMin<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : ?(K, V)
```


## Function `removeMax`
``` motoko no-repl
func removeMax<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : ?(K, V)
```


## Function `fromArray`
``` motoko no-repl
func fromArray<K, V>(btree_utils : BTreeUtils<K, V>, arr : [(K, V)], order : ?Nat) : MemoryBTree
```


## Function `fromEntries`
``` motoko no-repl
func fromEntries<K, V>(btree_utils : BTreeUtils<K, V>, entries : Iter<(K, V)>, order : ?Nat) : MemoryBTree
```


## Function `getCeiling`
``` motoko no-repl
func getCeiling<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ?(K, V)
```


## Function `getFloor`
``` motoko no-repl
func getFloor<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ?(K, V)
```


## Function `getFromIndex`
``` motoko no-repl
func getFromIndex<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, index : Nat) : (K, V)
```


## Function `getIndex`
``` motoko no-repl
func getIndex<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : Nat
```


## Function `range`
``` motoko no-repl
func range<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, start : Nat, end : Nat) : RevIter<(K, V)>
```


## Function `scan`
``` motoko no-repl
func scan<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, start : ?K, end : ?K) : RevIter<(K, V)>
```

