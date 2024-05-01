# MemoryBTree/modules/MemoryBlock
![MemoryBlock](./mem-block.png)
Instructions

|                            |    insert() |       get() |   replace() |  entries() |      remove() |
| :------------------------- | ----------: | ----------: | ----------: | ---------: | ------------: |
| B+Tree                     | 175_383_943 | 144_101_415 | 154_390_977 |  4_851_558 |   184_602_693 |
| MotokoStableBTree          | 807_443_679 |   3_564_997 | 807_444_791 |     11_835 |     2_817_599 |
| Memory B+Tree (order 4)    | 872_667_810 | 640_728_910 | 961_841_824 | 48_674_343 | 1_065_621_728 |

## Type `MemoryBTree`
``` motoko no-repl
type MemoryBTree = Migrations.MemoryBTree
```


## Type `Node`
``` motoko no-repl
type Node = Migrations.Node
```


## Type `MemoryBlock`
``` motoko no-repl
type MemoryBlock = T.MemoryBlock
```


## Function `id_exists`
``` motoko no-repl
func id_exists(btree : MemoryBTree, id : UniqueId) : Bool
```


## Function `store`
``` motoko no-repl
func store(btree : MemoryBTree, key : Blob, val : Blob) : UniqueId
```


## Function `next_id`
``` motoko no-repl
func next_id(btree : MemoryBTree) : UniqueId
```


## Function `get_ref_count`
``` motoko no-repl
func get_ref_count(btree : MemoryBTree, id : UniqueId) : Nat
```


## Function `increment_ref_count`
``` motoko no-repl
func increment_ref_count(btree : MemoryBTree, id : UniqueId)
```


## Function `decrement_ref_count`
``` motoko no-repl
func decrement_ref_count(btree : MemoryBTree, id : UniqueId) : Nat
```


## Function `replace_val`
``` motoko no-repl
func replace_val(btree : MemoryBTree, id : UniqueId, new_val : Blob)
```


## Function `get_key_blob`
``` motoko no-repl
func get_key_blob(btree : MemoryBTree, id : UniqueId) : Blob
```


## Function `get_key_block`
``` motoko no-repl
func get_key_block(btree : MemoryBTree, id : UniqueId) : MemoryBlock
```


## Function `get_val_block`
``` motoko no-repl
func get_val_block(btree : MemoryBTree, id : UniqueId) : MemoryBlock
```


## Function `get_val_blob`
``` motoko no-repl
func get_val_blob(btree : MemoryBTree, id : UniqueId) : Blob
```


## Function `remove`
``` motoko no-repl
func remove(btree : MemoryBTree, id : UniqueId)
```

