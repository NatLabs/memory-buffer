## MemoryBuffer
A persistent buffer implementation in motoko which makes use of the [memory-region](https://github.com/NatLabs/memory-region) library for re-allocating stable memory. The **MemoryBuffer** addresses the limitatons of heap storage by storing its elements in stable memory, which has the capacity to store significantly more data, up to 400 GiB.

> Note that this library is still in development and hasn't been tested for production use. If you find any bugs or have any suggestions, please open an issue [here](https://github.com/NatLabs/memory-buffer/issues).

### How It Works
The buffer is built using two [Region](https://internetcomputer.org/docs/current/motoko/main/base/Region/) modules:

- **Blob Region**: Stores all your elements as blobs in stable memory, re-allocating memory as needed. 
    > Memory allocation in the **Blob Region** is not contiguous, as elements at a specific index may be removed and the memory block reused for an element at a different index in size or may be removed from the buffer.
- **Pointer Region**: Keeps track of the address and size of the elements in the Blob Region. 
    > This region is contiguous and all its pointers have the same number of bytes in memory.

#### Pros and Cons
- **Pros**
  - Allows for random access to elements with different byte sizes.
  - Prevents internal fragmentation, a common issue in designs where each element is allocated a memory block equivalent to the maximum element's size.
- **Cons**
  - 12 bytes of overhead per element
    - 8 bytes for the address where the blob of the element is stored
    - 4 bytes for the size of the element
  - Each element's size when converted to a `Blob` must be between 1 and 4 GiB.
  - Additional instructions and heap allocations required for storing and retrieving free memory blocks.
  - Could potentially cause external fragmentation during memory block reallocations, resulting in a number small blocks that sum up to the needed size but can't be re-allocated because they are not contiguous.

## Getting Started
#### Installation
- Install [mops](https://docs.mops.one/quick-start)
- Run `mops add memory-buffer` in your project directory
  
#### Import modules

```motoko
  import { MemoryBufferClass; Blobify; VersionedMemoryBuffer; MemoryBuffer; } "mo:memory-buffer";
```
- **Blobify**: A module that provides functions for serializing and deserializing elements.
- **MemoryBuffer**: The base module for the buffer.
- **VersionedMemoryBuffer**: A module over the `MemoryBuffer` that stores the version and makes it easy to upgrade to a new version.
- **MemoryBufferClass**: A module over the `VersionedMemoryBuffer` that provides a class-like interface.

The `MemoryBufferClass` is recommended for general use.

#### Usage Examples
```motoko
  stable var mem_store = MemoryBufferClass.newStableStore<Nat>();

  let buffer = MemoryBufferClass.MemoryBufferClass<Nat>(mem_store, Blobify.Nat);
  buffer.add(1);
  buffer.add(3);
  buffer.insert(1, 2);
  assert buffer.toArray() == [1, 2, 3];

  for (i in Iter.range(0, buffer.size(mem_buffer) - 1)) {
    let n = buffer.get(i);
    buffer.put(i, n ** 2);
  };

  assert buffer.toArray() == [1, 4, 9];
  assert buffer.remove(1) == ?4;
  assert buffer.removeLast() == ?9;
```

#### Upgrading to a new version
The MemoryRegion that stores deallocated memory for future use is under development and may have breaking changes in the future. 
To account for this, the `MemoryBuffer` has a versioning system that allows you to upgrade without losing your data.

Steps to upgrade:
- Install new version via mops: `mops add memory-buffer@<version>`
- Call `upgrade()` on the buffer's memory store to upgrade to the new version.
- Replace the old memory store with the upgraded one.

```motoko
  stable var mem_store = MemoryBufferClass.newStableStore<Nat>();
  mem_store := MemoryBufferClass.upgrade(mem_store);
```

## Benchmarks
### Buffer vs MemoryBuffer
Benchmarking the performance with 10k `Nat` entries

- **put()** (new == prev) - updating elements in the buffer where number of bytes of the new element is equal to the number of bytes of the previous element
- **put() (new > prev)** - updating elements in the buffer where number of bytes of the new element is greater than the number of bytes of the previous element
- **sortUnstable()** - quicksort on the buffer - an unstable sort algorithm
- **blobSortUnstable()** - sorting without serializing the elements. Requires that the elements can be ordered in their serialized form.

#### Instructions

| Methods             |        Buffer | MemoryBuffer (with Blobify) | MemoryBuffer (encode to candid) |
| :-----------------  | ------------: | --------------------------: | ------------------------------: |
| add()               |     4_631_833 |                  55_658_661 |                      44_562_899 |
| get()               |     2_502_548 |                  31_701_506 |                      26_405_254 |
| put() (new == prev) |     3_893_438 |                  40_179_267 |                      29_082_693 |
| put() (new > prev)  |     4_557_396 |                 488_531_847 |                     213_209_278 |
| put() (new < prev)  |     4_235_067 |                 160_451_767 |                     157_396_508 |
| add() reallocation  |     8_868_304 |                 290_079_559 |                     159_519_128 |
| removeLast()        |     4_687_991 |                 130_619_001 |                     123_008_684 |
| reverse()           |     3_120_905 |                  10_433_404 |                      10_428_189 |
| remove()            | 3_692_128_841 |                 542_861_160 |                     537_722_525 |
| insert()            | 3_283_583_528 |                 769_441_766 |                     495_334_102 |
| sortUnstable()      |   101_307_554 |               7_918_240_085 |                   6_744_921_414 |
| blobSortUnstable()  |         6_850 |                 903_626_714 |                   1_083_497_533 |

#### Heap

| Methods             |    Buffer | MemoryBuffer (with Blobify) | MemoryBuffer (encode to candid) |
| :------------------ | --------: | --------------------------: | ------------------------------: |
| add()               |     9_008 |                     752_584 |                         610_008 |
| get()               |     9_008 |                   1_144_752 |                         369_040 |
| put() (new == prev) |     9_008 |                     752_572 |                         609_980 |
| put() (new > prev)  |     9_012 |                  14_117_144 |                       3_267_348 |
| put() (new < prev)  |     9_012 |                   2_161_364 |                       2_093_712 |
| add() reallocation  |   158_984 |                   5_701_172 |                       3_002_856 |
| removeLast()        |     8_960 |                   2_135_000 |                       1_340_248 |
| reverse()           |     8_952 |                     249_008 |                         249_008 |
| remove()            |    57_720 |                   3_169_784 |                       2_437_324 |
| insert()            |   154_900 |                  16_765_672 |                       5_884_108 |
| sortUnstable()      | 2_523_784 |                  29_739_268 |                      19_556_996 |
| blobSortUnstable()  |     8_992 |                  18_777_960 |                      25_562_276 |


#### Allocated Stable Memory Bytes

|                  | MemoryBuffer (with Blobify)                                                                                                                           | MemoryBuffer (encode to candid)                                                                                                                        |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| add()            | bytes:                         35_720<br>metadataBytes:       120_064<br>capacity:                    65_536<br>metadataCapacity:  131_072            | bytes:                         108_475<br>metadataBytes:        120_064<br>capacity:                    131_072<br>metadataCapacity:   131_072         |
| put () new > old | bytes:                         48_143<br>metadataBytes:       120_064<br>capacity:                    65_536<br>metadataCapacity:  131_072            | bytes:                         126_007<br>metadataBytes:        120_064<br>capacity:                   196_608<br>metadataCapacity:   131_072          |
| put () new < old | bytes:                         19_809<br>metadataBytes:       120_064<br>capacity:                    65_536<br>metadataCapacity:  131_072            | bytes:                          89_936<br>metadataBytes:        120_064<br>capacity:                   196_608<br>metadataCapacity:   131_072          |
| remove()         | bytes:                                  64<br>metadataBytes:                 64<br>capacity:                    65_536<br>metadataCapacity:   131_072 | bytes:                                  64<br>metadataBytes:                  64<br>capacity:                   196_608<br>metadataCapacity:   131_072 |
> Generate benchmarks by running `mops bench` in the project directory.

Encoding to Candid is more efficient than using a custom encoding function.
However, a custom encoding can be implemented to use less stable memory because it's more flexible and is not required to store the type information with the serialized data.


