# MemoryBTree/Migrations/lib

## Type `MemoryBTree`
``` motoko no-repl
type MemoryBTree = V0.MemoryBTree
```


## Type `Leaf`
``` motoko no-repl
type Leaf = V0.Leaf
```


## Type `Node`
``` motoko no-repl
type Node = V0.Node
```


## Type `Branch`
``` motoko no-repl
type Branch = V0.Branch
```


## Type `VersionedMemoryBTree`
``` motoko no-repl
type VersionedMemoryBTree = {#v0 : V0.MemoryBTree}
```


## Function `upgrade`
``` motoko no-repl
func upgrade(versions : VersionedMemoryBTree) : VersionedMemoryBTree
```


## Function `getCurrentVersion`
``` motoko no-repl
func getCurrentVersion(versions : VersionedMemoryBTree) : MemoryBTree
```

