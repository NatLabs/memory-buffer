import Prelude "mo:base/Prelude";
import TextModule "mo:base/Text";
import BlobModule "mo:base/Blob";
import ArrayModule "mo:base/Array";
import Nat8Module "mo:base/Nat8";
import NatModule "mo:base/Nat";

module {
    
    public type Blobify<A> = {
        to_blob: (A) -> Blob;
        from_blob: (Blob) -> A;
    };

    public let Nat = {
        to_blob = func (n: Nat): Blob {
            if (n == 0) { return "/00"};
            
            var num = n;
            var nbytes = 0;

            while (num > 0){
                num /= 10;
                nbytes += 1;
            };

            num := n;

            let arr = ArrayModule.tabulate(
                nbytes,
                func(i: Nat): Nat8 {
                    let tmp = num % 10;
                    num /= 10;
                    Nat8Module.fromNat(tmp)
                }
            );

            BlobModule.fromArray(arr)
        };
        from_blob = func (blob: Blob): Nat {
            var n = 0;
            var i = 0;
            let bytes = BlobModule.toArray(blob);
            
            for (byte in bytes.vals()){
                n *= NatModule.pow(10, bytes.size() - i - 1);
                n += Nat8Module.toNat(byte);

                i+= 1;
            };

            n
        }
    };

    public let Nat8 = {
        to_blob = func (n: Nat8): Blob = to_candid(n);
        from_blob = func (blob: Blob): Nat8 {
            let ?x : ?Nat8 = from_candid(blob) else Prelude.unreachable();
            x
        }
    };

    public let Nat16 = {
        to_blob = func (n: Nat16): Blob = to_candid(n);
        from_blob = func (blob: Blob): Nat16 {
            let ?x : ?Nat16 = from_candid(blob) else Prelude.unreachable();
            x
        }
    };

    public let Nat32 = {
        to_blob = func (n: Nat32): Blob = to_candid(n);
        from_blob = func (blob: Blob): Nat32 {
            let ?x : ?Nat32 = from_candid(blob) else Prelude.unreachable();
            x
        }
    };

    public let Nat64 = {
        to_blob = func (n: Nat64): Blob = to_candid(n);
        from_blob = func (blob: Blob): Nat64 {
            let ?x : ?Nat64 = from_candid(blob) else Prelude.unreachable();
            x
        }
    };

    public let Blob = {
        to_blob = func (b: Blob): Blob = b;
        from_blob = func (blob: Blob): Blob = blob;
    };

    public let Bool = {
        to_blob = func (b: Bool): Blob = BlobModule.fromArray([if (b) 1 else 0]);
        from_blob = func (blob: Blob): Bool {
            blob == BlobModule.fromArray([1])
        }
    };

    public let Text = {
        to_blob = func (t: Text): Blob = TextModule.encodeUtf8(t);
        from_blob = func (blob: Blob): Text {
            let ?text = TextModule.decodeUtf8(blob) else Prelude.unreachable();
            text
        }
    };

    public let t_blob = Text;
    public let b_blob = Blob;
    public let n_blob = Nat;
    public let n8_blob = Nat8;
    public let n16_blob = Nat16;
    public let n32_blob = Nat32;
    public let n64_blob = Nat64;
};