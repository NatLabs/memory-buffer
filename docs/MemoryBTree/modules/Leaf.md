# MemoryBTree/modules/Leaf

## Type `Leaf`
``` motoko no-repl
type Leaf = Migrations.Leaf
```


## Value `HEADER_SIZE`
``` motoko no-repl
let HEADER_SIZE
```


## Value `MAGIC_START`
``` motoko no-repl
let MAGIC_START
```


## Value `MAGIC_SIZE`
``` motoko no-repl
let MAGIC_SIZE
```


## Value `NODE_TYPE_START`
``` motoko no-repl
let NODE_TYPE_START
```


## Value `NODE_TYPE_SIZE`
``` motoko no-repl
let NODE_TYPE_SIZE
```


## Value `LAYOUT_VERSION_START`
``` motoko no-repl
let LAYOUT_VERSION_START
```


## Value `LAYOUT_VERSION_SIZE`
``` motoko no-repl
let LAYOUT_VERSION_SIZE
```


## Value `INDEX_START`
``` motoko no-repl
let INDEX_START
```


## Value `INDEX_SIZE`
``` motoko no-repl
let INDEX_SIZE
```


## Value `COUNT_START`
``` motoko no-repl
let COUNT_START
```


## Value `COUNT_SIZE`
``` motoko no-repl
let COUNT_SIZE
```


## Value `PARENT_START`
``` motoko no-repl
let PARENT_START
```


## Value `ADDRESS_SIZE`
``` motoko no-repl
let ADDRESS_SIZE
```


## Value `PREV_START`
``` motoko no-repl
let PREV_START
```


## Value `NEXT_START`
``` motoko no-repl
let NEXT_START
```


## Value `KV_IDS_START`
``` motoko no-repl
let KV_IDS_START
```


## Value `AC`
``` motoko no-repl
let AC
```


## Value `NULL_ADDRESS`
``` motoko no-repl
let NULL_ADDRESS : Nat64
```


## Value `MAGIC`
``` motoko no-repl
let MAGIC : Blob
```


## Value `LAYOUT_VERSION`
``` motoko no-repl
let LAYOUT_VERSION : Nat8
```


## Value `NODE_TYPE`
``` motoko no-repl
let NODE_TYPE : Nat8
```


## Function `get_memory_size`
``` motoko no-repl
func get_memory_size(btree : MemoryBTree) : Nat
```

Leaf Memory Layout

|     Field      |     Size    | Offset |   Type   |                              Description                              |
|----------------|-------------|--------|----------|-----------------------------------------------------------------------|
| MAGIC          | 3           | 0      | Blob     | Magic number                                                          |
| NODE TYPE      | 1           | 3      | Nat8     | Node type                                                             |
| LAYOUT VERSION | 1           | 4      | Nat8     | Layout version                                                        |
| INDEX          | 2           | 5      | Nat16    | Node's position in parent node                                        |
| COUNT          | 2           | 7      | Nat16    | Number of elements in the node                                        |
| PARENT         | 8           | 9      | Nat64    | Parent address                                                        |
| PREV           | 8           | 17     | Nat64    | Previous leaf address                                                 |
| NEXT           | 8           | 25     | Nat64    | Next leaf address                                                     |
| EXTRA          | 31          | 33     | -        | Extra space from header (size 64) for future use                      |
| KV unique Ids  | 8 * order   | 64     | Nat64    | Unique ids for each key-value pair stored in the blocks memory region |

## Function `get_kv_id_offset`
``` motoko no-repl
func get_kv_id_offset(leaf_address : Nat, i : Nat) : Nat
```


## Function `new`
``` motoko no-repl
func new(btree : MemoryBTree) : Nat
```


## Function `validate`
``` motoko no-repl
func validate(btree : MemoryBTree, address : Nat) : Bool
```


## Function `from_memory`
``` motoko no-repl
func from_memory(btree : MemoryBTree, address : Nat) : Leaf
```


## Function `from_memory_into`
``` motoko no-repl
func from_memory_into(btree : MemoryBTree, address : Nat, leaf : Leaf, load_keys : Bool)
```


## Function `add_to_cache`
``` motoko no-repl
func add_to_cache(btree : MemoryBTree, address : Nat)
```


## Function `display`
``` motoko no-repl
func display(btree : MemoryBTree, btree_utils : BTreeUtils<Nat, Nat>, leaf_address : Nat)
```


## Function `get_count`
``` motoko no-repl
func get_count(btree : MemoryBTree, address : Nat) : Nat
```


## Function `get_kv_id`
``` motoko no-repl
func get_kv_id(btree : MemoryBTree, address : Nat, i : Nat) : ?UniqueId
```


## Function `get_key_block`
``` motoko no-repl
func get_key_block(btree : MemoryBTree, address : Nat, i : Nat) : ?MemoryBlock
```


## Function `get_val_block`
``` motoko no-repl
func get_val_block(btree : MemoryBTree, address : Nat, i : Nat) : ?MemoryBlock
```


## Function `get_key_blob`
``` motoko no-repl
func get_key_blob(btree : MemoryBTree, address : Nat, i : Nat) : ?(Blob)
```


## Function `set_key_to_null`
``` motoko no-repl
func set_key_to_null(btree : MemoryBTree, address : Nat, i : Nat)
```


## Function `get_val_blob`
``` motoko no-repl
func get_val_blob(btree : MemoryBTree, address : Nat, index : Nat) : ?(Blob)
```


## Function `set_kv_to_null`
``` motoko no-repl
func set_kv_to_null(btree : MemoryBTree, address : Nat, i : Nat)
```


## Function `get_kv_blobs`
``` motoko no-repl
func get_kv_blobs(btree : MemoryBTree, address : Nat, index : Nat) : ?(Blob, Blob)
```


## Function `get_parent`
``` motoko no-repl
func get_parent(btree : MemoryBTree, address : Nat) : ?Nat
```


## Function `get_index`
``` motoko no-repl
func get_index(btree : MemoryBTree, address : Nat) : Nat
```


## Function `get_next`
``` motoko no-repl
func get_next(btree : MemoryBTree, address : Nat) : ?Nat
```


## Function `get_prev`
``` motoko no-repl
func get_prev(btree : MemoryBTree, address : Nat) : ?Nat
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
func update_count(btree : MemoryBTree, address : Nat, new_count : Nat)
```


## Function `update_index`
``` motoko no-repl
func update_index(btree : MemoryBTree, address : Nat, new_index : Nat)
```


## Function `update_parent`
``` motoko no-repl
func update_parent(btree : MemoryBTree, address : Nat, opt_parent : ?Nat)
```


## Function `update_next`
``` motoko no-repl
func update_next(btree : MemoryBTree, address : Nat, opt_next : ?Nat)
```


## Function `update_prev`
``` motoko no-repl
func update_prev(btree : MemoryBTree, address : Nat, opt_prev : ?Nat)
```


## Function `clear`
``` motoko no-repl
func clear(btree : MemoryBTree, leaf_address : Nat)
```


## Function `insert`
``` motoko no-repl
func insert(btree : MemoryBTree, leaf_address : Nat, index : Nat, new_id : UniqueId)
```


## Function `insert_with_count`
``` motoko no-repl
func insert_with_count(btree : MemoryBTree, leaf_address : Nat, index : Nat, new_id : UniqueId, count : Nat)
```


## Function `put`
``` motoko no-repl
func put(btree : MemoryBTree, leaf_address : Nat, index : Nat, new_id : UniqueId)
```


## Function `split`
``` motoko no-repl
func split(btree : MemoryBTree, leaf_address : Nat, elem_index : Nat, new_id : UniqueId) : Nat
```


## Function `shift`
``` motoko no-repl
func shift(btree : MemoryBTree, leaf_address : Nat, start : Nat, end : Nat, offset : Int)
```


## Function `remove`
``` motoko no-repl
func remove(btree : MemoryBTree, leaf_address : Nat, index : Nat)
```


## Function `redistribute`
``` motoko no-repl
func redistribute(btree : MemoryBTree, leaf : Nat, neighbour : Nat) : Bool
```


## Function `deallocate`
``` motoko no-repl
func deallocate(btree : MemoryBTree, leaf : Nat)
```


## Function `merge`
``` motoko no-repl
func merge(btree : MemoryBTree, leaf : Nat, neighbour : Nat)
```

