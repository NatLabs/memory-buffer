## MemoryBuffer
A persistent buffer implementation in motoko which makes use of the [memory-region](https://github.com/NatLabs/memory-region) library for re-allocating stable memory. The **MemoryBuffer** addresses the limitatons of heap storage by storing its elements in stable memory, which has the capacity to store significantly more data, up to 64 GiB.

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
  import { MemoryBuffer; Blobify } "mo:memory-buffer";
```
#### Usage Examples
```motoko
  stable let mem_buffer = MemoryBuffer.new<Nat>();

  MemoryBuffer.add(mem_buffer, Blobify.Nat, 1);
  MemoryBuffer.add(mem_buffer, Blobify.Nat, 3);
  MemoryBuffer.insert(mem_buffer, Blobify.Nat, 1, 2);
  assert MemoryBuffer.toArray(mem_buffer, Blobify.Nat) == [1, 2, 3];

  for (i in Iter.range(0, MemoryBuffer.size(mem_buffer) - 1)) {
    let n = MemoryBuffer.get(mem_buffer, Blobify.Nat, i);
    MemoryBuffer.put(mem_buffer, Blobify.Nat, i, n ** 2);
  };

  assert MemoryBuffer.toArray(mem_buffer, Blobify.Nat) == [1, 4, 9];
  assert MemoryBuffer.remove(mem_buffer, Blobify.Nat, 1) == ?4;
  assert MemoryBuffer.removeLast(mem_buffer, Blobify.Nat) == ?9;
```

## Benchmarks
### Buffer vs MemoryBuffer
Benchmarking the performance with 10k entries

- **add()** - adding elements to the end of the buffer
- **get()** - retrieving elements from the buffer
- **put()** (new == prev) - updating elements in the buffer where number of bytes of the new element is equal to the number of bytes of the previous element
- **put() (new > prev)** - updating elements in the buffer where number of bytes of the new element is greater than the number of bytes of the previous element
- **remove()** - removing the first element in the buffer till the buffer is empty resulting in the worst case scenario
- **insert()** - inserting elements at the beginning of the buffer till the buffer has 10k elements resulting in the worst case scenario
- **removeLast()** - removing the last element in the buffer till the buffer is empty

#### Instructions

| Methods             |         Buffer |  MemoryBuffer |
| :------------------ | -------------: | ------------: |
| add()               |      7_506_635 |    37_471_730 |
| get()               |      2_442_253 |    22_743_302 |
| put() (new == prev) |      2_803_133 |    26_629_193 |
| put() (new > prev)  |      3_143_921 |    89_478_142 |
| remove()            | 10_855_068_046 | 1_438_465_552 |
| insert()            |  9_555_436_925 | 1_374_513_438 |
| removeLast()        |      5_543_704 |   377_115_486 |


#### Heap
| Methods             |  Buffer | MemoryBuffer |
| :------------------ | ------: | -----------: |
| add()               | 154_740 |      687_984 |
| get()               |   9_008 |      762_888 |
| put() (new == prev) |   9_008 |      687_936 |
| put() (new > prev)  |   9_008 |    1_711_632 |
| remove()            |  57_716 |    3_441_436 |
| insert()            | 154_896 |    2_305_752 |
| removeLast()        |  57_700 |    6_300_332 |


> Generate benchmarks by running `mops bench` in the project directory.

## Future Work
- Improve perfomance. 
  - Reduce the number of instructions and heap allocations required for each operation.