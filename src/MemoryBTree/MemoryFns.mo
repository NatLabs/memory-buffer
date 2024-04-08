import Int "mo:base/Int";
import Array "mo:base/Array";
import Order "mo:base/Order";
import Debug "mo:base/Debug";

import MemoryRegion "mo:memory-region/MemoryRegion";
import MemoryUtils "MemoryUtils";
import T "Types";

module {
    type MemoryRegion = MemoryRegion.MemoryRegion;
    type Order = Order.Order;
    type MemoryBTree = T.MemoryBTree;
    type MemoryUtils<K, V> = T.MemoryUtils<K, V>;

    public func shift(region : MemoryRegion, start : Nat, end : Nat, offset : Int) {
        let size = (end - start : Nat);

        let blob = MemoryRegion.loadBlob(region, start, size);

        let new_start = Int.abs(start + offset);

        MemoryRegion.storeBlob(region, new_start, blob);
    };

}