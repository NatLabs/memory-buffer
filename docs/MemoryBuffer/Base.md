# MemoryBuffer/Base
This is the base implementation of a persistent buffer that stores its values in stable memory.
The buffer employs two memory regions to store the values and the pointers to the memory blocks where the values are stored.
The buffer grows by a factor of `√(P)`, where `P` is the total number of pages previously allocated.

In addition to the expected buffer functions, the buffer add or remove values from either ends of the buffer in O(1) time.


# Memory Region Layout

## Value Blob Region
This region stores the serialized values in the buffer.

|           Field          | Offset | Size |  Type  | Value |                                Description                              |
|--------------------------|--------|------|--------|-------|-------------------------------------------------------------------------|
| Magic Number             |  0     |  3   | Blob   | "BLB" | Magic Number used to identify the Blob Region                           |
| Layout Version           |  3     |  1   | Nat8   | 0     | Layout Version detailing how the data in the region is structured       |
| Buffer Metadata Region   |  4     |  4   | Nat32  | -     | Region Id of the Buffer Metadata Region that it is attached to                 |
| Reserved Header Space    |  8     |  56  | -      | -     | Reserved Space for future use if the layout needs to be updated         |
| Value * `N`              |  64    |  -   | Blob   | -     | N number of arbitrary sized values, serialized and stored in the region |

## Buffer Metadata Region
This region stores the metadata and pointers to the Blob Region.

|           Field          | Offset |   Size    |     Type      |  Value  |                                Description                              |
|--------------------------|--------|-----------|---------------|---------|-------------------------------------------------------------------------|
| Magic Number             |  0     |  3        | Blob          | "BLB"   | Magic Number for identifying the Buffer Region                          |
| Layout Version           |  3     |  1        | Nat8          | 0 or 1  | Layout Version detailing how the data in the region is structured       |
| Blob Region ID           |  4     |  4        | Nat32         | -       | Region Id of the Blob Region attached to itself                         |
| Count                    |  8     |  8        | Nat64         | -       | Number of elements stored in the buffer                                 |
| Start Index              |  16    |  8        | Nat64         | -       | Internal index where the first value is stored in the buffer            |
| Prev Pages Allocated     |  24    |  4        | Nat32         | -       | Number of pages allocated during the resize operation                   |
| Extra Header Space       |  28    |  36       | -             | -       | Reserved Space for future use if the layout needs to be updated         |
| Pointer * `N`            |  64    |  12 * `N` | Nat64 # Nat32 | -       | Pointers to the memory blocks in the Blob Region. It stores the concatenated memory block offset (8 bytes) and size (4 bytes) |


## Type `MemoryBufferRegion`
``` motoko no-repl
type MemoryBufferRegion = { pointers : MemoryRegion; blobs : MemoryRegion }
```


## Type `MemoryBuffer`
``` motoko no-repl
type MemoryBuffer<A> = Migrations.MemoryBuffer<A>
```


## Type `VersionedMemoryBuffer`
``` motoko no-repl
type VersionedMemoryBuffer<A> = Migrations.VersionedMemoryBuffer<A>
```


## Value `REGION_HEADER_SIZE`
``` motoko no-repl
let REGION_HEADER_SIZE
```


## Value `POINTER_SIZE`
``` motoko no-repl
let POINTER_SIZE
```


## Value `LAYOUT_VERSION`
``` motoko no-repl
let LAYOUT_VERSION
```


## Type `Blobify`
``` motoko no-repl
type Blobify<A> = Blobify.Blobify<A>
```

The Blobify typeclass is used to serialize and deserialize values.

## Function `new`
``` motoko no-repl
func new<A>() : MemoryBuffer<A>
```

Creates a new memory buffer.

## Function `verify`
``` motoko no-repl
func verify(region : MemoryBufferRegion) : Result<(), Text>
```


## Function `fromVersioned`
``` motoko no-repl
func fromVersioned<A>(self : VersionedMemoryBuffer<A>) : MemoryBuffer<A>
```

Converts from a versioned memory buffer

## Function `toVersioned`
``` motoko no-repl
func toVersioned<A>(self : MemoryBuffer<A>) : VersionedMemoryBuffer<A>
```

Converts the memory buffer to a versioned one.

## Function `init`
``` motoko no-repl
func init<A>(blobify : Blobify<A>, size : Nat, val : A) : MemoryBuffer<A>
```

Initializes a memory buffer with a given value and size.

## Function `tabulate`
``` motoko no-repl
func tabulate<A>(blobify : Blobify<A>, size : Nat, fn : (i : Nat) -> A) : MemoryBuffer<A>
```

Initializes a memory buffer with a given function and size.

## Function `fromArray`
``` motoko no-repl
func fromArray<A>(blobify : Blobify<A>, arr : [A]) : MemoryBuffer<A>
```

Initializes a memory buffer with a given array.

## Function `fromIter`
``` motoko no-repl
func fromIter<A>(blobify : Blobify<A>, iter : Iter<A>) : MemoryBuffer<A>
```


## Function `size`
``` motoko no-repl
func size<A>(self : MemoryBuffer<A>) : Nat
```

Returns the number of elements in the buffer.

## Function `bytes`
``` motoko no-repl
func bytes<A>(self : MemoryBuffer<A>) : Nat
```

Returns the number of bytes used for storing the values in the buffer.

## Function `metadataBytes`
``` motoko no-repl
func metadataBytes<A>(self : MemoryBuffer<A>) : Nat
```

Returns the bytes used for storing the metadata which include the pointers, buffer size, and region headers.

## Function `totalBytes`
``` motoko no-repl
func totalBytes<A>(self : MemoryBuffer<A>) : Nat
```


## Function `capacity`
``` motoko no-repl
func capacity<A>(self : MemoryBuffer<A>) : Nat
```

Returns the number of elements that can be stored in the buffer before it needs to grow.

## Function `_get_pointer`
``` motoko no-repl
func _get_pointer<A>(index : Nat) : Nat
```


## Function `get_circular_index`
``` motoko no-repl
func get_circular_index<A>(self : MemoryBuffer<A>, index : Int) : Nat
```

Returns the internal index where the value at the given index is stored.

## Function `_get_memory_address`
``` motoko no-repl
func _get_memory_address<A>(self : MemoryBuffer<A>, index : Nat) : Nat
```


## Function `_get_memory_size`
``` motoko no-repl
func _get_memory_size<A>(self : MemoryBuffer<A>, index : Nat) : Nat
```


## Function `add`
``` motoko no-repl
func add<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, value : A)
```

Adds a value to the end of the buffer.

## Function `addFromArray`
``` motoko no-repl
func addFromArray<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, values : [A])
```

Adds all the values from the given array to the end of the buffer.

## Function `addFromIter`
``` motoko no-repl
func addFromIter<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, iter : Iter<A>)
```

Adds all the values from the given iterator to the end of the buffer.

## Function `addFirst`
``` motoko no-repl
func addFirst<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, value : A)
```

Adds a value to the beginning of the buffer.

## Function `addLast`
``` motoko no-repl
func addLast<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, value : A)
```

Adds a value to the end of the buffer.

## Function `put`
``` motoko no-repl
func put<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat, value : A)
```

Replaces the value at the given index with the given value.

## Function `getOpt`
``` motoko no-repl
func getOpt<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : ?A
```

Retrieves the value at the given index if it exists. Otherwise returns null.

## Function `_get_blob`
``` motoko no-repl
func _get_blob<A>(self : MemoryBuffer<A>, index : Nat) : Blob
```


## Function `get`
``` motoko no-repl
func get<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : A
```

Retrieves the value at the given index. Traps if the index is out of bounds.

## Function `_get_memory_block`
``` motoko no-repl
func _get_memory_block<A>(self : MemoryBuffer<A>, index : Nat) : (Nat, Nat)
```


## Function `append`
``` motoko no-repl
func append<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, other : MemoryBuffer<A>)
```

Adds all the values from the given buffer to the end of this buffer.

## Function `appendArray`
``` motoko no-repl
func appendArray<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, blobs : [A])
```

Adds all the values from the given array to the end of this buffer.

## Function `appendBuffer`
``` motoko no-repl
func appendBuffer<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, other : { vals : () -> Iter<A> })
```

Adds all the values from the given buffer to the end of this buffer.

## Function `keys`
``` motoko no-repl
func keys<A>(self : MemoryBuffer<A>) : RevIter<Nat>
```


## Function `vals`
``` motoko no-repl
func vals<A>(self : MemoryBuffer<A>, blobify : Blobify<A>) : RevIter<A>
```

Returns an iterator over the values in the buffer.

## Function `range`
``` motoko no-repl
func range<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, start : Nat, end : Nat) : RevIter<A>
```

Returns an iterator over the values in the given range.

```motoko
    let buffer = MemoryBuffer.fromArray(Blobify.int, [1, 2, 3, 4, 5]);
    let iter = MemoryBuffer.range(Blobify.int, 1, 3);
    assert Iter.toArray(iter) == [2, 3];
```

## Function `items`
``` motoko no-repl
func items<A>(self : MemoryBuffer<A>, blobify : Blobify<A>) : RevIter<(index : Nat, value : A)>
```

Return an iterator over the indices and values in the buffer.

## Function `itemsRange`
``` motoko no-repl
func itemsRange<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, start : Nat, end : Nat) : RevIter<(index : Nat, value : A)>
```


## Function `blobs`
``` motoko no-repl
func blobs<A>(self : MemoryBuffer<A>) : RevIter<Blob>
```

An iterator over the serialized blobs in the buffer.

## Function `pointers`
``` motoko no-repl
func pointers<A>(self : MemoryBuffer<A>) : RevIter<Nat>
```

An iterator over the pointers to the memory blocks where the serialized values are stored.
The iterator returns the address of the pointer because the size of each pointer is fixed at 12 bytes.

## Function `blocks`
``` motoko no-repl
func blocks<A>(self : MemoryBuffer<A>) : RevIter<(Nat, Nat)>
```

An iterator over the memory blocks where the serialized values are stored.

## Function `remove`
``` motoko no-repl
func remove<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : A
```

Removes the value at the given index. Traps if the index is out of bounds.

## Function `removeFirst`
``` motoko no-repl
func removeFirst<A>(self : MemoryBuffer<A>, blobify : Blobify<A>) : ?A
```


## Function `removeLast`
``` motoko no-repl
func removeLast<A>(self : MemoryBuffer<A>, blobify : Blobify<A>) : ?A
```

Removes the last value in the buffer, if it exists. Otherwise returns null.

## Function `insert`
``` motoko no-repl
func insert<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat, value : A)
```

Inserts a value at the given index.

## Function `swap`
``` motoko no-repl
func swap<A>(self : MemoryBuffer<A>, index_a : Nat, index_b : Nat)
```

Swaps the values at the given indices.

## Function `swapRemove`
``` motoko no-repl
func swapRemove<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : A
```

Swaps the value at the given index with the last index, so that it can be removed in O(1) time.

## Function `reverse`
``` motoko no-repl
func reverse<A>(self : MemoryBuffer<A>)
```

Reverses the order of the values in the buffer.

## Function `clear`
``` motoko no-repl
func clear<A>(self : MemoryBuffer<A>)
```

Clears the buffer.

## Function `clone`
``` motoko no-repl
func clone<A>(self : MemoryBuffer<A>) : MemoryBuffer<A>
```


## Function `sortUnstable`
``` motoko no-repl
func sortUnstable<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, mem_cmp : MemoryCmp.MemoryCmp<A>)
```

Sorts the values in the buffer in ascending order.
This is an implementation of the quicksort algorithm.
The algorithm is unstable and has an average time complexity of O(n log n).

## Function `shuffle`
``` motoko no-repl
func shuffle<A>(self : MemoryBuffer<A>)
```

Randomizes the order of the values in the buffer.

## Function `indexOf`
``` motoko no-repl
func indexOf<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, equal : (A, A) -> Bool, element : A) : ?Nat
```


## Function `lastIndexOf`
``` motoko no-repl
func lastIndexOf<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, equal : (A, A) -> Bool, element : A) : ?Nat
```


## Function `contains`
``` motoko no-repl
func contains<A>(self : MemoryBuffer<A>, blobify : Blobify<A>, equal : (A, A) -> Bool, element : A) : Bool
```


## Function `isEmpty`
``` motoko no-repl
func isEmpty<A>(self : MemoryBuffer<A>) : Bool
```


## Function `first`
``` motoko no-repl
func first<A>(self : MemoryBuffer<A>, blobify : Blobify<A>) : A
```


## Function `last`
``` motoko no-repl
func last<A>(self : MemoryBuffer<A>, blobify : Blobify<A>) : A
```


## Function `peekFirst`
``` motoko no-repl
func peekFirst<A>(self : MemoryBuffer<A>, blobify : Blobify<A>) : ?A
```


## Function `peekLast`
``` motoko no-repl
func peekLast<A>(self : MemoryBuffer<A>, blobify : Blobify<A>) : ?A
```


## Function `toArray`
``` motoko no-repl
func toArray<A>(self : MemoryBuffer<A>, blobify : Blobify<A>) : [A]
```

Converts a memory buffer to an array.
