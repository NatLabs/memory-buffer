# MemoryBTree/modules/Types

## Type `Address`
``` motoko no-repl
type Address = Nat
```


## Type `UniqueId`
``` motoko no-repl
type UniqueId = Nat
```


## Type `MemoryBlock`
``` motoko no-repl
type MemoryBlock = (Address, Size)
```


## Type `MemoryCmp`
``` motoko no-repl
type MemoryCmp<A> = MemoryCmp.MemoryCmp<A>
```


## Type `BTreeUtils`
``` motoko no-repl
type BTreeUtils<K, V> = { key : Blobify<K>; val : Blobify<V>; cmp : MemoryCmp<K> }
```


## Type `NodeType`
``` motoko no-repl
type NodeType = {#branch; #leaf}
```

