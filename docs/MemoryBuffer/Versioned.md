# MemoryBuffer/Versioned
Versioned Module for the MemoryBuffer

This module provides a this wrapper around the base MemoryBuffer module that add versioning for easy
upgrades to future versions without breaking compatibility with existing code.

## Type `Blobify`
``` motoko no-repl
type Blobify<A> = Blobify.Blobify<A>
```


## Type `MemoryBuffer`
``` motoko no-repl
type MemoryBuffer<A> = Migrations.MemoryBuffer<A>
```


## Type `VersionedMemoryBuffer`
``` motoko no-repl
type VersionedMemoryBuffer<A> = Migrations.VersionedMemoryBuffer<A>
```


## Function `new`
``` motoko no-repl
func new<A>() : VersionedMemoryBuffer<A>
```


## Function `upgrade`
``` motoko no-repl
func upgrade<A>(self : VersionedMemoryBuffer<A>) : VersionedMemoryBuffer<A>
```


## Function `verify`
``` motoko no-repl
func verify<A>(self : VersionedMemoryBuffer<A>) : Result<(), Text>
```


## Function `init`
``` motoko no-repl
func init<A>(self : Blobify<A>, size : Nat, val : A) : VersionedMemoryBuffer<A>
```


## Function `tabulate`
``` motoko no-repl
func tabulate<A>(blobify : Blobify<A>, size : Nat, fn : (i : Nat) -> A) : VersionedMemoryBuffer<A>
```


## Function `fromArray`
``` motoko no-repl
func fromArray<A>(blobify : Blobify<A>, arr : [A]) : VersionedMemoryBuffer<A>
```


## Function `fromIter`
``` motoko no-repl
func fromIter<A>(blobify : Blobify<A>, iter : Iter<A>) : VersionedMemoryBuffer<A>
```


## Function `size`
``` motoko no-repl
func size<A>(self : VersionedMemoryBuffer<A>) : Nat
```


## Function `bytes`
``` motoko no-repl
func bytes<A>(self : VersionedMemoryBuffer<A>) : Nat
```


## Function `metadataBytes`
``` motoko no-repl
func metadataBytes<A>(self : VersionedMemoryBuffer<A>) : Nat
```


## Function `totalBytes`
``` motoko no-repl
func totalBytes<A>(self : VersionedMemoryBuffer<A>) : Nat
```


## Function `capacity`
``` motoko no-repl
func capacity<A>(self : VersionedMemoryBuffer<A>) : Nat
```


## Function `put`
``` motoko no-repl
func put<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, index : Nat, value : A)
```


## Function `getOpt`
``` motoko no-repl
func getOpt<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : ?A
```


## Function `get`
``` motoko no-repl
func get<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : A
```


## Function `addFirst`
``` motoko no-repl
func addFirst<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, value : A)
```


## Function `addLast`
``` motoko no-repl
func addLast<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, value : A)
```


## Function `addFromIter`
``` motoko no-repl
func addFromIter<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, iter : Iter<A>)
```


## Function `addFromArray`
``` motoko no-repl
func addFromArray<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, arr : [A])
```


## Function `add`
``` motoko no-repl
func add<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, value : A)
```


## Function `append`
``` motoko no-repl
func append<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, other : VersionedMemoryBuffer<A>)
```


## Function `vals`
``` motoko no-repl
func vals<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>) : RevIter<A>
```


## Function `items`
``` motoko no-repl
func items<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>) : RevIter<(index : Nat, value : A)>
```


## Function `blobs`
``` motoko no-repl
func blobs<A>(self : VersionedMemoryBuffer<A>) : RevIter<Blob>
```


## Function `pointers`
``` motoko no-repl
func pointers<A>(self : VersionedMemoryBuffer<A>) : RevIter<Nat>
```


## Function `blocks`
``` motoko no-repl
func blocks<A>(self : VersionedMemoryBuffer<A>) : RevIter<(Nat, Nat)>
```


## Function `remove`
``` motoko no-repl
func remove<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : A
```


## Function `removeFirst`
``` motoko no-repl
func removeFirst<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>) : ?A
```


## Function `removeLast`
``` motoko no-repl
func removeLast<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>) : ?A
```


## Function `swap`
``` motoko no-repl
func swap<A>(self : VersionedMemoryBuffer<A>, index_a : Nat, index_b : Nat)
```


## Function `swapRemove`
``` motoko no-repl
func swapRemove<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : A
```


## Function `reverse`
``` motoko no-repl
func reverse<A>(self : VersionedMemoryBuffer<A>)
```


## Function `clear`
``` motoko no-repl
func clear<A>(self : VersionedMemoryBuffer<A>)
```


## Function `clone`
``` motoko no-repl
func clone<A>(self : VersionedMemoryBuffer<A>) : VersionedMemoryBuffer<A>
```


## Function `insert`
``` motoko no-repl
func insert<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, index : Nat, value : A)
```


## Function `sortUnstable`
``` motoko no-repl
func sortUnstable<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, cmp : MemoryCmp.MemoryCmp<A>)
```


## Function `shuffle`
``` motoko no-repl
func shuffle<A>(self : VersionedMemoryBuffer<A>)
```


## Function `indexOf`
``` motoko no-repl
func indexOf<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, equal : (A, A) -> Bool, value : A) : ?Nat
```


## Function `lastIndexOf`
``` motoko no-repl
func lastIndexOf<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, equal : (A, A) -> Bool, value : A) : ?Nat
```


## Function `contains`
``` motoko no-repl
func contains<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, equal : (A, A) -> Bool, value : A) : Bool
```


## Function `isEmpty`
``` motoko no-repl
func isEmpty<A>(self : VersionedMemoryBuffer<A>) : Bool
```


## Function `first`
``` motoko no-repl
func first<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>) : A
```


## Function `last`
``` motoko no-repl
func last<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>) : A
```


## Function `peekFirst`
``` motoko no-repl
func peekFirst<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>) : ?A
```


## Function `peekLast`
``` motoko no-repl
func peekLast<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>) : ?A
```


## Function `toArray`
``` motoko no-repl
func toArray<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>) : [A]
```

