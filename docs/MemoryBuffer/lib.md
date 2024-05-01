# MemoryBuffer/lib
The `MemoryBuffer` is an object wrapper around the [BaseMemoryBuffer module](../BaseMemoryBuffer) BaseMemoryBuffer. 
It provides a more user-friendly interface opting for methods exposed from the object instead of top-level module functions.

There are three different modules available for this datastructure:
- [Base MemoryBuffer](../Base) - The base module that provides the core functionality for the memory buffer.
- [Versioned MemoryBuffer](../Versioned) - The versioned module that supports seamless upgrades without losing data.
- MemoryBuffer Class - Class that wraps the versioned module and provides a more user-friendly interface.

It is recommended to use the MemoryBuffer Class for most use-cases.


## Type `BaseMemoryBuffer`
``` motoko no-repl
type BaseMemoryBuffer<A> = Migrations.MemoryBuffer<A>
```


## Type `VersionedMemoryBuffer`
``` motoko no-repl
type VersionedMemoryBuffer<A> = Migrations.VersionedMemoryBuffer<A>
```


## Function `newStableStore`
``` motoko no-repl
func newStableStore<A>() : VersionedMemoryBuffer<A>
```

Creates a new stable store for the memory buffer.

## Function `upgrade`
``` motoko no-repl
func upgrade<A>(versions : VersionedMemoryBuffer<A>) : VersionedMemoryBuffer<A>
```

Upgrades the memory buffer to the latest version.

## Class `MemoryBuffer<A>`

``` motoko no-repl
class MemoryBuffer<A>(versions : VersionedMemoryBuffer<A>, blobify : Blobify<A>)
```


### Function `add`
``` motoko no-repl
func add(elem : A)
```

Adds an element to the end of the buffer.


### Function `get`
``` motoko no-repl
func get(i : Nat) : A
```

Returns the element at the given index.


### Function `size`
``` motoko no-repl
func size() : Nat
```

Returns the number of elements in the buffer.


### Function `bytes`
``` motoko no-repl
func bytes() : Nat
```

Returns the number of bytes used to store the serialized elements in the buffer.


### Function `metadataBytes`
``` motoko no-repl
func metadataBytes() : Nat
```

Returns the number of bytes used to store the metadata and memory block pointers.


### Function `capacity`
``` motoko no-repl
func capacity() : Nat
```

Returns the number of elements the buffer can hold before resizing.


### Function `put`
``` motoko no-repl
func put(i : Nat, elem : A)
```

Overwrites the element at the given index with the new element.


### Function `getOpt`
``` motoko no-repl
func getOpt(i : Nat) : ?A
```

Returns the element at the given index or `null` if the index is out of bounds.


### Function `addFirst`
``` motoko no-repl
func addFirst(elem : A)
```

Adds an element before the first element in the buffer.
Runtime: `O(1)`


### Function `addLast`
``` motoko no-repl
func addLast(elem : A)
```

Adds an element after the last element in the buffer. Alias for `add()`.
Runtime: `O(1)`


### Function `addFromIter`
``` motoko no-repl
func addFromIter(iter : Iter<A>)
```

Adds all elements from the given iterator to the end of the buffer.


### Function `addFromArray`
``` motoko no-repl
func addFromArray(arr : [A])
```

Adds all elements from the given array to the end of the buffer.


### Function `vals`
``` motoko no-repl
func vals() : RevIter<A>
```

Returns a reversable iterator over the elements in the buffer.

```motoko
    stable var sstore = MemoryBuffer.newStableStore<Text>();
    sstore := MemoryBuffer.upgrade(sstore);
    
    let buffer = MemoryBuffer.MemoryBuffer<Text>(sstore, Blobify.Text);

    buffer.addFromArray(["a", "b", "c"]);

    let vals = Iter.toArray(buffer.vals());
    assert vals == ["a", "b", "c"];

    let reversed = Iter.toArray(buffer.vals().rev());
    assert reversed == ["c", "b", "a"];
```


### Function `items`
``` motoko no-repl
func items() : RevIter<(Nat, A)>
```

Returns a reversable iterator over a tuple of the index and element in the buffer.


### Function `blobs`
``` motoko no-repl
func blobs() : RevIter<Blob>
```

Returns a reversable iterator over the serialized elements in the buffer.


### Function `swap`
``` motoko no-repl
func swap(i : Nat, j : Nat)
```

Swaps the elements at the given indices.


### Function `swapRemove`
``` motoko no-repl
func swapRemove(i : Nat) : A
```

Swaps the element at the given index with the last element in the buffer and removes it.


### Function `remove`
``` motoko no-repl
func remove(i : Nat) : A
```

Removes the element at the given index.


### Function `removeFirst`
``` motoko no-repl
func removeFirst() : ?A
```

Removes the first element in the buffer.

```motoko
    stable var sstore = MemoryBuffer.newStableStore<Text>();
    sstore := MemoryBuffer.upgrade(sstore);
    
    let buffer = MemoryBuffer.MemoryBuffer<Nat>(sstore, Blobify.Nat); // little-endian

    buffer.addFromArray([1, 2, 3]);

    assert buffer.removeFirst() == ?1;
```


### Function `removeLast`
``` motoko no-repl
func removeLast() : ?A
```

Removes the last element in the buffer.


### Function `insert`
``` motoko no-repl
func insert(i : Nat, elem : A)
```

Inserts an element at the given index.


### Function `sortUnstable`
``` motoko no-repl
func sortUnstable(cmp : MemoryCmp.MemoryCmp<A>)
```

Sorts the elements in the buffer using the given comparison function.
This function implements quicksort, an unstable sorting algorithm with an average time complexity of `O(n log n)`.
It also supports a comparision function that can either compare the elements the default type or in their serialized form as blobs.
For more information on the comparison function, refer to the [MemoryCmp module](../MemoryCmp).


### Function `shuffle`
``` motoko no-repl
func shuffle()
```

Randomly shuffles the elements in the buffer.


### Function `reverse`
``` motoko no-repl
func reverse()
```

Reverse the order of the elements in the buffer.


### Function `indexOf`
``` motoko no-repl
func indexOf(equal : (A, A) -> Bool, elem : A) : ?Nat
```

Returns the index of the first element that is equal to the given element.


### Function `lastIndexOf`
``` motoko no-repl
func lastIndexOf(equal : (A, A) -> Bool, elem : A) : ?Nat
```

Returns the index of the last element that is equal to the given element.


### Function `contains`
``` motoko no-repl
func contains(equal : (A, A) -> Bool, elem : A) : Bool
```

Returns `true` if the buffer contains the given element.


### Function `isEmpty`
``` motoko no-repl
func isEmpty() : Bool
```

Returns `true` if the buffer is empty.


### Function `first`
``` motoko no-repl
func first() : A
```

Returns the first element in the buffer. Traps if the buffer is empty.


### Function `last`
``` motoko no-repl
func last() : A
```

Returns the last element in the buffer. Traps if the buffer is empty.


### Function `peekFirst`
``` motoko no-repl
func peekFirst() : ?A
```

Returns the first element in the buffer or `null` if the buffer is empty.


### Function `peekLast`
``` motoko no-repl
func peekLast() : ?A
```

Returns the last element in the buffer or `null` if the buffer is empty.


### Function `clear`
``` motoko no-repl
func clear()
```

Removes all elements from the buffer.


### Function `toArray`
``` motoko no-repl
func toArray() : [A]
```

Copies all the elements in the buffer to a new array.


### Function `_getInternalRegion`
``` motoko no-repl
func _getInternalRegion() : BaseMemoryBuffer<A>
```



### Function `_getBlobifyFn`
``` motoko no-repl
func _getBlobifyFn() : Blobify<A>
```


## Function `toArray`
``` motoko no-repl
func toArray<A>(mbuffer : MemoryBuffer<A>) : [A]
```

