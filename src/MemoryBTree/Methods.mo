module {
    // public func new_iterator<K, V>(
    //     btree : MemoryBTree,
    //     mem_utils : MemoryUtils<K, V>,
    //     start_leaf : Leaf,
    //     start_index : Nat,
    //     end_leaf : Leaf,
    //     end_index : Nat // exclusive
    // ) : RevIter<(K, V)> {

    //     var _start_leaf = ?start_leaf;
    //     var i = start_index;

    //     var _end_leaf = ?end_leaf;
    //     var j = end_index;

    //     func next() : ?(K, V) {
    //         let ?start = _start_leaf else return null;
    //         let ?end = _end_leaf else return null;

    //         if (start.0[C.ID] == end.0[C.ID] and i >= j) {
    //             _start_leaf := null;
    //             return null;
    //         };

    //         if (i >= start.0[C.COUNT]) {
    //             _start_leaf := start.2[C.NEXT];
    //             i := 0;
    //             return next();
    //         };

    //         let entry = start.3[i];
    //         i += 1;
    //         return entry;
    //     };

    //     func nextFromEnd() : ?(K, V) {
    //         let ?start = _start_leaf else return null;
    //         let ?end = _end_leaf else return null;

    //         if (start.0[C.ID] == end.0[C.ID] and i >= j) {
    //             _end_leaf := null;
    //             return null;
    //         };

    //         if (j == 0) {
    //             _end_leaf := end.2[C.PREV];
    //             switch (_end_leaf) {
    //                 case (?leaf) j := leaf.0[C.COUNT];
    //                 case (_) { return null };
    //             };

    //             return nextFromEnd();
    //         };

    //         let entry = end.3[j - 1];
    //         j -= 1;
    //         return entry;
    //     };

    //     RevIter.new(next, nextFromEnd);
    // };

    // public func vals<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>) : RevIter<(K, V)> {
    //     let leaf = get_node(btree, btree.root);

    //     var i = 0;
    //     var j 
    //     let count = leaf.0 [C.COUNT];
    //     let kv_offset = leaf.0 [C.ADDRESS] + Leaf.KV_START;

    //     Iter.init<V> {
    //         hasNext: {
    //             i < count;
    //         },
    //         next: {
    //             let ptr = kv_offset + (i * Leaf.KV_MEMORY_BLOCK_SIZE);
    //             let value_blob = MemoryRegion.loadBlob(btree.blobs, ptr + Leaf.MAX_KEY_SIZE, Leaf.MAX_VALUE_SIZE);
    //             i += 1;
    //             mem_utils.1.from_blob(value_blob);
    //         },
    //     };

    //     func next() : ?(K, V) {

    //     };

    //     RevIter.new(next, nextFromEnd);
    // };
}