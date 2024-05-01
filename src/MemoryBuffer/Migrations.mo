/// A memory buffer is a data structure that stores a sequence of values in memory.

import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Order "mo:base/Order";
import Debug "mo:base/Debug";

import MemoryRegion "mo:memory-region/MemoryRegion";

module Migrations {
    type Iter<A> = Iter.Iter<A>;
    type Result<A, B> = Result.Result<A, B>;
    type MemoryRegion = MemoryRegion.MemoryRegion;

    type MemoryRegionV0 = MemoryRegion.MemoryRegionV0;
    type MemoryRegionV1 = MemoryRegion.MemoryRegionV1;

    type Order = Order.Order;

    // current version of the memory buffer
    public type MemoryBuffer<A> = MemoryBufferV1<A>;

    public type VersionedMemoryBuffer<A> = {
        #v0 : MemoryBufferV0<A>;
        #v1 : MemoryBufferV1<A>;
    };

    public func upgrade<A>(versions: VersionedMemoryBuffer<A>) : VersionedMemoryBuffer<A> = switch(versions){
        case (#v0(v0)) {
            let v1 : MemoryBufferV1 <A> = {
                pointers = v0.pointers;
                blobs = v0.blobs;
                var count = v0.count;
                var start = 0;
                var prev_pages_allocated = 0;
            };

            /// initialize the values missing in the pointers region header
            MemoryRegion.storeNat64(v1.pointers, LayoutV1.START_ADDRESS, 0); // |8 bytes| Start Address -> Start of the pointers region
            MemoryRegion.storeNat32(v1.pointers, LayoutV1.PREV_PAGES_ALLOCATED_START, 0); // |4 bytes| Number of pages to allocate when growing the buffer. Increments by 1 each time the buffer grows.
            
            return #v1(v1);
        };
        case (#v1(v1)) versions;
    };

    public func getCurrentVersion<A>(versions: VersionedMemoryBuffer<A>) : MemoryBuffer<A> {
        switch(versions){
            case (#v1(v1)) v1;
            case (_) Debug.trap("Unsupported version. Please upgrade the memory buffer to the latest version.");
        };
    };
    
    public type MemoryBufferV1<A> = {
        /// The memory region that stores the pointers to the serialized values.
        pointers : MemoryRegionV1;

        /// The memory region that stores the serialized values.
        blobs : MemoryRegionV1;

        /// The number of values in the buffer.
        var count : Nat;

        /// The index of the first value in the buffer.
        var start : Nat;

        /// The number of pages previously allocated, 
        /// incremented by 1 each time the buffer needs to grow.
        var prev_pages_allocated : Nat;
    };

    public let LayoutV1 = {
        MAGIC_NUMBER_ADDRESS = 0;
        LAYOUT_VERSION_ADDRESS = 3;
        REGION_ID_ADDRESS = 4;
        COUNT_ADDRESS = 8;
        START_ADDRESS = 16;
        PREV_PAGES_ALLOCATED_START = 24;
        POINTERS_START = 64;
        BLOB_START = 64;
    };

    /// Initial version of the memory buffer
    public type MemoryBufferV0<A> = {
        /// The memory region that stores the pointers to the serialized values.
        pointers : MemoryRegionV1;

        /// The memory region that stores the serialized values.
        blobs : MemoryRegionV1;

        /// The number of values in the buffer.
        var count : Nat;
    };

    public let LayoutV0 = {
        MAGIC_NUMBER_ADDRESS = 0;
        LAYOUT_VERSION_ADDRESS = 3;
        REGION_ID_ADDRESS = 4;
        COUNT_ADDRESS = 8;
        POINTERS_START = 64;
        BLOB_START = 64;
    };

    
    public let Layout = (
        LayoutV0,
        LayoutV1
    );

};