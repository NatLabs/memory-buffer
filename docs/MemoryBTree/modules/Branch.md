# MemoryBTree/modules/Branch
Branch Memory Layout

|     Field      |     Size      | Offset          |   Type   |                              Description                              |
|----------------|---------------|-----------------|----------|-----------------------------------------------------------------------|
| MAGIC          | 3             | 0               | Blob     | Magic number                                                          |
| NODE TYPE      | 1             | 3               | Nat8     | Node type                                                             |
| LAYOUT VERSION | 1             | 4               | Nat8     | Layout version                                                        |
| INDEX          | 2             | 5               | Nat16    | Node's position in parent node                                        |
| COUNT          | 2             | 7               | Nat16    | Number of elements in the node                                        |
| SUBTREE COUNT  | 8             | 9               | Nat64    | Number of elements in the node's subtree                              |
| PARENT         | 8             | 17              | Nat64    | Parent address                                                        |
| Extra space    | 47            | 25              | -        | Extra space for future use                                            |
| Ids            | 8 * order - 1 | 64              | Nat64    | Unique ids for each key stored in the branch                          |
| Children       | 8 * order     | 64 + size(Ids)  | Nat64    | Addresses of children nodes                                           |
|-------------------------------------------------------------------------------------------------------------------------------------|

## Type `Branch`
``` motoko no-repl
type Branch = Migrations.Branch
```


## Value `AC`
``` motoko no-repl
let AC
```


## Value `MC`
``` motoko no-repl
let MC
```


## Function `get_memory_size`
``` motoko no-repl
func get_memory_size(btree : MemoryBTree) : Nat
```


## Function `CHILDREN_START`
``` motoko no-repl
func CHILDREN_START(btree : MemoryBTree) : Nat
```


## Function `get_key_id_offset`
``` motoko no-repl
func get_key_id_offset(branch_address : Nat, i : Nat) : Nat
```


## Function `get_child_offset`
``` motoko no-repl
func get_child_offset(btree : MemoryBTree, branch_address : Nat, i : Nat) : Nat
```


## Function `new`
``` motoko no-repl
func new(btree : MemoryBTree) : Nat
```


## Function `from_memory`
``` motoko no-repl
func from_memory(btree : MemoryBTree, branch_address : Address) : Branch
```


## Function `add_to_cache`
``` motoko no-repl
func add_to_cache(btree : MemoryBTree, address : Nat)
```


## Function `rm_from_cache`
``` motoko no-repl
func rm_from_cache(btree : MemoryBTree, address : Address)
```


## Function `display`
``` motoko no-repl
func display(btree : MemoryBTree, btree_utils : BTreeUtils<Nat, Nat>, branch_address : Nat)
```


## Function `update_index`
``` motoko no-repl
func update_index(btree : MemoryBTree, branch_address : Nat, new_index : Nat)
```


## Function `put_key_id`
``` motoko no-repl
func put_key_id(btree : MemoryBTree, branch_address : Nat, i : Nat, key_id : UniqueId)
```


## Function `put_child`
``` motoko no-repl
func put_child(btree : MemoryBTree, branch_address : Nat, i : Nat, child_address : Nat)
```


## Function `get_node_subtree_size`
``` motoko no-repl
func get_node_subtree_size(btree : MemoryBTree, node_address : Address) : Nat
```


## Function `add_child`
``` motoko no-repl
func add_child(btree : MemoryBTree, branch_address : Nat, child_address : Nat)
```


## Function `get_node_type`
``` motoko no-repl
func get_node_type(btree : MemoryBTree, node_address : Nat) : NodeType
```


## Function `get_count`
``` motoko no-repl
func get_count(btree : MemoryBTree, branch_address : Nat) : Nat
```


## Function `get_index`
``` motoko no-repl
func get_index(btree : MemoryBTree, branch_address : Nat) : Nat
```


## Function `get_parent`
``` motoko no-repl
func get_parent(btree : MemoryBTree, branch_address : Nat) : ?Nat
```


## Function `get_key_id`
``` motoko no-repl
func get_key_id(btree : MemoryBTree, branch_address : Nat, i : Nat) : ?UniqueId
```


## Function `get_key_blob`
``` motoko no-repl
func get_key_blob(btree : MemoryBTree, branch_address : Nat, i : Nat) : ?(Blob)
```


## Function `set_key_id_to_null`
``` motoko no-repl
func set_key_id_to_null(btree : MemoryBTree, branch_address : Nat, i : Nat)
```


## Function `get_child`
``` motoko no-repl
func get_child(btree : MemoryBTree, branch_address : Nat, i : Nat) : ?Nat
```


## Function `set_child_to_null`
``` motoko no-repl
func set_child_to_null(btree : MemoryBTree, branch_address : Nat, i : Nat)
```


## Function `get_subtree_size`
``` motoko no-repl
func get_subtree_size(btree : MemoryBTree, branch_address : Nat) : Nat
```


## Function `binary_search`
``` motoko no-repl
func binary_search<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, address : Nat, cmp : (K, K) -> Int8, search_key : K, arr_len : Nat) : Int
```


## Function `binary_search_blob_seq`
``` motoko no-repl
func binary_search_blob_seq(btree : MemoryBTree, address : Nat, cmp : (Blob, Blob) -> Int8, search_key : Blob, arr_len : Nat) : Int
```


## Function `update_count`
``` motoko no-repl
func update_count(btree : MemoryBTree, branch_address : Nat, count : Nat)
```


## Function `update_subtree_size`
``` motoko no-repl
func update_subtree_size(btree : MemoryBTree, branch_address : Nat, new_size : Nat)
```


## Function `update_parent`
``` motoko no-repl
func update_parent(btree : MemoryBTree, branch_address : Nat, opt_parent : ?Nat)
```


## Function `update_median_key_id`
``` motoko no-repl
func update_median_key_id(btree : MemoryBTree, parent_address : Nat, child_index : Nat, new_key_id : UniqueId)
```


## Function `insert`
``` motoko no-repl
func insert(btree : MemoryBTree, branch_address : Nat, i : Nat, key_id : UniqueId, child_address : Nat)
```


## Function `split`
``` motoko no-repl
func split(btree : MemoryBTree, branch_address : Nat, child_index : Nat, child_key_id : UniqueId, child : Nat) : Nat
```


## Function `get_larger_neighbour`
``` motoko no-repl
func get_larger_neighbour(btree : MemoryBTree, parent_address : Address, index : Nat) : ?Address
```


## Function `shift`
``` motoko no-repl
func shift(btree : MemoryBTree, branch : Address, start : Nat, end : Nat, offset : Int)
```


## Function `remove`
``` motoko no-repl
func remove(btree : MemoryBTree, branch : Address, index : Nat)
```


## Function `redistribute`
``` motoko no-repl
func redistribute(btree : MemoryBTree, branch : Address) : Bool
```


## Function `deallocate`
``` motoko no-repl
func deallocate(btree : MemoryBTree, branch : Address)
```


## Function `merge`
``` motoko no-repl
func merge(btree : MemoryBTree, branch : Address, neighbour : Address) : (deallocated_branch : Address)
```

