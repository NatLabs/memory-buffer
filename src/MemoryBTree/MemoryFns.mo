import Int "mo:base/Int";
import Array "mo:base/Array";
import Order "mo:base/Order";
import Debug "mo:base/Debug";

import MemoryRegion "mo:memory-region/MemoryRegion";
import MemoryUtils "../MemoryBTree/MemoryUtils";
import T "Types";
import MemoryBlock "./MemoryBlock";

module {
    type MemoryRegion = MemoryRegion.MemoryRegion;
    type Order = Order.Order;
    type MemoryBTree = T.MemoryBTree;
    type MemoryBlock = T.MemoryBlock;
    type MemoryUtils<K, V> = T.MemoryUtils<K, V>;

    public func shift(region : MemoryRegion, start : Nat, end : Nat, bytes : Int) {
        let size = (end - start : Nat);

        let blob = MemoryRegion.loadBlob(region, start, size);

        let new_start = if (bytes >= 0) {
            Int.abs(start + bytes)
        } else {
            Int.abs(start - bytes)
        };

        MemoryRegion.storeBlob(region, new_start, blob);
    };

}