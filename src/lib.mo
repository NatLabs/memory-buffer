import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Iter "mo:base/Iter";

import MemoryRegion "mo:memory-region/MemoryRegion";

import Utils "Utils";
import BlobifyModule "Blobify";
import MemoryBufferModule "MemoryBuffer";

module {
    public let MemoryBuffer = MemoryBufferModule;
    public type Blobify<A> = BlobifyModule.Blobify<A>;
    public let Blobify = BlobifyModule;

    public type MemoryBTree = MemoryBTreeModule.MemoryBTree;
    public let MemoryBTree = MemoryBTreeModule;

    public type MemoryBTreeClass<K, V> = MemoryBTreeClassModule.MemoryBTreeClass<K, V>;
    public let MemoryBTreeClass = MemoryBTreeClassModule;

    public type VersionedMemoryBTree = VersionedMemoryBTreeModule.VersionedMemoryBTree;
    public let VersionedMemoryBTree = VersionedMemoryBTreeModule;
};
