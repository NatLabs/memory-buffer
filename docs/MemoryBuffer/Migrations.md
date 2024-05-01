# MemoryBuffer/Migrations
A memory buffer is a data structure that stores a sequence of values in memory.

## Type `MemoryBuffer`
``` motoko no-repl
type MemoryBuffer<A> = MemoryBufferV1<A>
```


## Type `VersionedMemoryBuffer`
``` motoko no-repl
type VersionedMemoryBuffer<A> = {#v0 : MemoryBufferV0<A>; #v1 : MemoryBufferV1<A>}
```


## Function `upgrade`
``` motoko no-repl
func upgrade<A>(versions : VersionedMemoryBuffer<A>) : VersionedMemoryBuffer<A>
```


## Function `getCurrentVersion`
``` motoko no-repl
func getCurrentVersion<A>(versions : VersionedMemoryBuffer<A>) : MemoryBuffer<A>
```


## Type `MemoryBufferV1`
``` motoko no-repl
type MemoryBufferV1<A> = { pointers : MemoryRegionV1; blobs : MemoryRegionV1; var count : Nat; var start : Nat; var prev_pages_allocated : Nat }
```


## Value `LayoutV1`
``` motoko no-repl
let LayoutV1
```


## Type `MemoryBufferV0`
``` motoko no-repl
type MemoryBufferV0<A> = { pointers : MemoryRegionV1; blobs : MemoryRegionV1; var count : Nat }
```

Initial version of the memory buffer

## Value `LayoutV0`
``` motoko no-repl
let LayoutV0
```


## Value `Layout`
``` motoko no-repl
let Layout
```

