## MemoryBuffer
A persistent buffer implementation in motoko which makes use of the [memory-region]() library for re-allocation memory. This buffer supports elements of arbitrary sizes (no need to specify the max size of the elements).

This library is still  in development and hasn't tested for production use. If you find any bugs or have any suggestions, please open an issue [here]().

### How It Works
The buffer is built using two Region modules:

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
  - Could potentially causes external fragmentation during memory block reallocations, resulting in a number small blocks that sum up to the needed size but cannot be used as they are scattered across the memory region and not contiguous.

## Usage
- Import the necessary modules
```motoko
  import { MemoryBuffer; Blobify } "mo:memory-buffer";
```
- 
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
- removeLast() - removing the last element in the buffer till the buffer is empty

#### Instructions

|-             |      add() |      get() | put() (new == prev) | put() (new > prev) |       remove() |      insert() | removeLast() |
| :----------- | ---------: | ---------: | ------------------: | -----------------: | -------------: | ------------: | -----------: |
| Buffer       |  7_506_635 |  2_442_253 |           2_803_133 |          3_143_921 | 10_855_068_046 | 9_555_436_925 |    5_543_704 |
| MemoryBuffer | 54_470_575 | 39_346_739 |          44_582_289 |        301_024_818 |  1_509_550_380 | 1_275_731_638 |  298_371_818 |


#### Heap

|-             |     add() |     get() | put() (new == prev) | put() (new > prev) |  remove() |  insert() | removeLast() |
| :----------- | --------: | --------: | ------------------: | -----------------: | --------: | --------: | -----------: |
| Buffer       |   154_740 |     9_008 |               9_008 |              9_008 |    57_716 |   154_896 |       57_660 |
| MemoryBuffer | 1_604_516 | 1_484_576 |           1_804_516 |          8_114_116 | 6_918_196 | 1_767_860 |    6_631_468 |

## Future Work
- Improve perfomance. 
  - Reduce the number of instructions and heap allocations required for each operation.