import BlobifyModule "Blobify";
import MemoryBufferModule "MemoryBuffer/Base";
import MemoryBufferClassModule "MemoryBuffer/Class";
import VersionedMemoryBufferModule "MemoryBuffer/Versioned";

import MemoryBTreeModule "MemoryBTree/Base";

module {
    public let MemoryBuffer = MemoryBufferModule;
    public let MemoryBufferClass = MemoryBufferClassModule;
    public let VersionedMemoryBuffer = VersionedMemoryBufferModule;

    public type MemoryBuffer<A> = MemoryBufferModule.MemoryBuffer<A>;
    public type MemoryBufferClass<A> = MemoryBufferClassModule.MemoryBufferClass<A>;
    public type VersionedMemoryBuffer<A> = VersionedMemoryBufferModule.VersionedMemoryBuffer<A>;

    public type Blobify<A> = BlobifyModule.Blobify<A>;
    public let Blobify = BlobifyModule;

    public type MemoryBTree = MemoryBTreeModule.MemoryBTree;
    public let MemoryBTree = MemoryBTreeModule.MemoryBTree;
};
