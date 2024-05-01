# MemoryBTree/Class

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


## Function `newStableStore`
``` motoko no-repl
func newStableStore(order : ?Nat) : VersionedMemoryBTree
```

Create a new stable store

## Function `upgrade`
``` motoko no-repl
func upgrade<K, V>(versions : VersionedMemoryBTree) : VersionedMemoryBTree
```

Upgrade an older version of the BTree to the latest version 

## Class `MemoryBTreeClass<K, V>`

``` motoko no-repl
class MemoryBTreeClass<K, V>(versions : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>)
```

MemoryBTree class

### Function `get`
``` motoko no-repl
func get(key : K) : ?V
```

Get the value associated with a key


### Function `getMax`
``` motoko no-repl
func getMax() : ?(K, V)
```

Get the entry with the maximum key


### Function `getMin`
``` motoko no-repl
func getMin() : ?(K, V)
```

Get the entry with the minimum key


### Function `getCeiling`
``` motoko no-repl
func getCeiling(key : K) : ?(K, V)
```

Get the entry that either matches the key or is the next largest key


### Function `getFloor`
``` motoko no-repl
func getFloor(key : K) : ?(K, V)
```

Get the entry that either matches the key or is the next smallest key


### Function `getFromIndex`
``` motoko no-repl
func getFromIndex(i : Nat) : (K, V)
```

Get the entry at the given index in the sorted order


### Function `getIndex`
``` motoko no-repl
func getIndex(key : K) : Nat
```

Get the index (sorted position) of the given key in the btree


### Function `insert`
``` motoko no-repl
func insert(key : K, val : V) : ?V
```

Insert a new key-value pair into the BTree


### Function `remove`
``` motoko no-repl
func remove(key : K) : ?V
```

Remove the key-value pair associated with the given key


### Function `removeMax`
``` motoko no-repl
func removeMax() : ?(K, V)
```

Remove the entry with the maximum key


### Function `removeMin`
``` motoko no-repl
func removeMin() : ?(K, V)
```

Remove the entry with the minimum key


### Function `clear`
``` motoko no-repl
func clear()
```

Clear the BTree - Remove all entries from the BTree


### Function `entries`
``` motoko no-repl
func entries() : RevIter<(K, V)>
```

Returns a reversible iterator over the entries in the BTree


### Function `keys`
``` motoko no-repl
func keys() : RevIter<(K)>
```

Returns a reversible iterator over the keys in the BTree


### Function `vals`
``` motoko no-repl
func vals() : RevIter<(V)>
```

Returns a reversible iterator over the values in the BTree


### Function `range`
``` motoko no-repl
func range(i : Nat, j : Nat) : RevIter<(K, V)>
```

Returns a reversible iterator over the entries in the given range


### Function `scan`
``` motoko no-repl
func scan(start : ?K, end : ?K) : RevIter<(K, V)>
```

Returns a reversible iterator over the entries in the given range


### Function `size`
``` motoko no-repl
func size() : Nat
```

Returns the number of entries in the BTree


### Function `bytes`
``` motoko no-repl
func bytes() : Nat
```

Returns the number of bytes used to store the keys and values data


### Function `metadataBytes`
``` motoko no-repl
func metadataBytes() : Nat
```

Retuens the number of bytes used to store information about the nodes and structure of the BTree


### Function `getId`
``` motoko no-repl
func getId(key : K) : ?Nat
```

Functions for Unique Id References to values in the BTree
Get the id associated with a key


### Function `nextId`
``` motoko no-repl
func nextId() : Nat
```

Get the next available id that will be assigned to a new value


### Function `lookup`
``` motoko no-repl
func lookup(id : Nat) : ?(K, V)
```

Get the entry associated with the given id


### Function `lookupKey`
``` motoko no-repl
func lookupKey(id : Nat) : ?K
```

Get the key associated with the given id


### Function `lookupVal`
``` motoko no-repl
func lookupVal(id : Nat) : ?V
```

Get the value associated with the given id


### Function `reference`
``` motoko no-repl
func reference(id : Nat)
```

Reference a value by its id and increment the reference count
Values will not be removed from the BTree until the reference count is zero


### Function `getRefCount`
``` motoko no-repl
func getRefCount(id : Nat) : ?Nat
```

Get the reference count associated with the given id

## Function `fromArray`
``` motoko no-repl
func fromArray<K, V>(versions : VersionedMemoryBTree, btree_utils : BTreeUtils<K, V>, arr : [(K, V)]) : MemoryBTreeClass<K, V>
```


