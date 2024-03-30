import Prim "mo:prim";

import Blob "mo:base/Blob";

import Int8Cmp "Int8Cmp";
module {
    public type MemoryCmp<A> = {
        #cmp : (A, A) -> Int8;
        #blob_cmp : (Blob, Blob) -> Int8;
    };

    public let Default = #blob_cmp(Int8Cmp.Blob);

    // public let Nat = #cmp(Int8Cmp.Nat);
    public let Nat = #blob_cmp(
        func (a: Blob, b: Blob) : Int8 {
            if (a.size() > b.size()) return 1;
            if (a.size() < b.size()) return -1;

            let a_bytes = Blob.toArray(a);
            let b_bytes = Blob.toArray(b);

            var i = a_bytes.size();
            while (i > 0) {
                let j = i - 1;
                if (a_bytes[j] > b_bytes[j]) return 1;
                if (a_bytes[j] < b_bytes[j]) return -1;
                i -=1;
            };

            return 0;
        }
    );

    public let Nat8 = #blob_cmp(Prim.blobCompare);

    public let Nat16 = #blob_cmp(
        func (a: Blob, b: Blob) : Int8 {
            let a_bytes = Blob.toArray(a);
            let b_bytes = Blob.toArray(b);

            var i = a_bytes.size();
            while (i > 0) {
                let j = i - 1;
                if (a_bytes[j] > b_bytes[j]) return 1;
                if (a_bytes[j] < b_bytes[j]) return -1;
                i -=1;
            };

            return 0;
        }
    );
}