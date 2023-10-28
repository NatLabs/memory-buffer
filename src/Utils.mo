import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Prelude "mo:base/Prelude";
import Iter "mo:base/Iter";
import Result "mo:base/Result";

module {

    type Iter<A> = Iter.Iter<A>;
    type Result<A, B> = Result.Result<A, B>;
    
    public func send_error<OldOk, NewOk, Error>(res: Result<OldOk, Error>): Result<NewOk, Error>{
        switch (res) {
            case (#ok(_)) Prelude.unreachable();
            case (#err(errorMsg)) #err(errorMsg);
        };
    };
    
    public func nat_to_blob(num : Nat, nbytes : Nat) : Blob {
        var n = num;

        let bytes = Array.reverse(
            Array.tabulate(
                nbytes,
                func(_ : Nat) : Nat8 {
                    if (n == 0) {
                        return 0;
                    };

                    let byte = Nat8.fromNat(n % 256);
                    n /= 256;
                    byte;
                },
            )
        );

        return Blob.fromArray(bytes);
    };

    public func blob_to_nat(blob: Blob): Nat {
        var n = 0;

        for (byte in blob.vals()){
            n *= 256;
            n += Nat8.toNat(byte);
        };

        return n;
    };

    public func byte_iter_to_nat(iter: Iter<Nat8>): Nat {
        var n = 0;

        for (byte in iter){
            n *= 256;
            n += Nat8.toNat(byte);
        };

        return n;
    };

};
