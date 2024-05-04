# MemoryBTree/modules/Methods

## Type `Leaf`
``` motoko no-repl
type Leaf = Migrations.Leaf
```


## Type `BTreeUtils`
``` motoko no-repl
type BTreeUtils<K, V> = T.BTreeUtils<K, V>
```


## Type `Branch`
``` motoko no-repl
type Branch = Migrations.Branch
```


## Function `get_leaf_address`
``` motoko no-repl
func get_leaf_address<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K, _opt_key_blob : ?Blob) : Nat
```


## Function `get_leaf_address_and_update_path`
``` motoko no-repl
func get_leaf_address_and_update_path<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K, _opt_key_blob : ?Blob, update : (MemoryBTree, Nat, Nat) -> ()) : Nat
```


## Function `get_min_leaf_address`
``` motoko no-repl
func get_min_leaf_address(btree : MemoryBTree) : Nat
```


## Function `get_max_leaf_address`
``` motoko no-repl
func get_max_leaf_address(btree : MemoryBTree) : Nat
```


## Function `update_leaf_to_root`
``` motoko no-repl
func update_leaf_to_root(btree : MemoryBTree, leaf_address : Nat, update : (MemoryBTree, Nat, Nat) -> ())
```


## Function `update_branch_to_root`
``` motoko no-repl
func update_branch_to_root(btree : MemoryBTree, branch_address : Nat, update : (MemoryBTree, Nat, Nat) -> ())
```


## Function `get_leaf_node_and_index`
``` motoko no-repl
func get_leaf_node_and_index<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : Blob) : (Address, Nat)
```


## Function `get_leaf_node_by_index`
``` motoko no-repl
func get_leaf_node_by_index<K, V>(btree : MemoryBTree, rank : Nat) : (Address, Nat)
```


## Function `new_blobs_iterator`
``` motoko no-repl
func new_blobs_iterator(btree : MemoryBTree, start_leaf : Nat, start_index : Nat, end_leaf : Nat, end_index : Nat) : RevIter<(Blob, Blob)>
```


## Function `key_val_blobs`
``` motoko no-repl
func key_val_blobs(btree : MemoryBTree) : RevIter<(Blob, Blob)>
```


## Function `deserialize_kv_blobs`
``` motoko no-repl
func deserialize_kv_blobs<K, V>(btree_utils : BTreeUtils<K, V>, key_blob : Blob, val_blob : Blob) : (K, V)
```


## Function `entries`
``` motoko no-repl
func entries<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<(K, V)>
```


## Function `keys`
``` motoko no-repl
func keys<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<(K)>
```


## Function `vals`
``` motoko no-repl
func vals<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<(V)>
```


## Function `new_leaf_address_iterator`
``` motoko no-repl
func new_leaf_address_iterator(btree : MemoryBTree, start_leaf : Nat, end_leaf : Nat) : RevIter<Nat>
```


## Function `leaf_addresses`
``` motoko no-repl
func leaf_addresses(btree : MemoryBTree) : RevIter<Nat>
```


## Function `leaf_nodes`
``` motoko no-repl
func leaf_nodes<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<[?(K, V)]>
```


## Function `node_keys`
``` motoko no-repl
func node_keys<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : [[(Nat, [?K])]]
```


## Function `validate_memory`
``` motoko no-repl
func validate_memory(btree : MemoryBTree, btree_utils : BTreeUtils<Nat, Nat>) : Bool
```

