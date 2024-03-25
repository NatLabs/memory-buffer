import BlobifyModule "Blobify";
import MemoryBufferModule "MemoryBuffer";
import MemoryBufferClassModule "MemoryBufferClass";
import VersionedMemoryBufferModule "VersionedMemoryBuffer";

module {
    public let MemoryBuffer = MemoryBufferModule;
    public let MemoryBufferClass = MemoryBufferClassModule;
    public let VersionedMemoryBuffer = VersionedMemoryBufferModule;

    public type MemoryBuffer<A> = MemoryBufferModule.MemoryBuffer<A>;
    public type MemoryBufferClass<A> = MemoryBufferClassModule.MemoryBufferClass<A>;
    public type VersionedMemoryBuffer<A> = VersionedMemoryBufferModule.VersionedMemoryBuffer<A>;

    public type Blobify<A> = BlobifyModule.Blobify<A>;
    public let Blobify = BlobifyModule;
};
