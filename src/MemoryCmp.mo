import Blob "mo:base/Blob";
import Int8Cmp "Int8Cmp";
module {
    public type MemoryCmp<A> = {
        #cmp : (A, A) -> Int8;
        #blob_cmp : (Blob, Blob) -> Int8;
    };

    public let Default = #blob_cmp(Int8Cmp.Blob);
}