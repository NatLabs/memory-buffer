import Prelude "mo:base/Prelude";
import TextModule "mo:base/Text";
import BlobModule "mo:base/Blob";
import ArrayModule "mo:base/Array";
import NatModule "mo:base/Nat";
import Nat8Module "mo:base/Nat8";
import Nat16Module "mo:base/Nat16";
import Nat32Module "mo:base/Nat32";
import Nat64Module "mo:base/Nat64";
import PrincipalModule "mo:base/Principal";

import Debug "mo:base/Debug";
import Array "mo:base/Array";

module {

    let Base = {
        Array = ArrayModule;
        Blob = BlobModule;
        Nat = NatModule;
        Nat8 = Nat8Module;
        Nat16 = Nat16Module;
        Nat32 = Nat32Module;
        Nat64 = Nat64Module;
        Text = TextModule;
        Principal = PrincipalModule;
    };

    public type Blobify<A> = {
        to_blob : (A) -> Blob;
        from_blob : (Blob) -> A;
    };

    // Default blobify helpers return blobs in little-endian format.
    public let Nat = {
        to_blob = func(n : Nat) : Blob {
            if (n == 0) { return "\00" };
            var num = n;
            var nbytes = 0;

            while (num > 0) {
                num /= 255;
                nbytes += 1;
            };

            num := n;

            let arr = ArrayModule.tabulate(
                nbytes,
                func(i : Nat) : Nat8 {
                    let tmp = num % 255;
                    num /= 255;
                    Nat8Module.fromNat(tmp);
                },
            );

            Base.Blob.fromArray(arr);
        };
        from_blob = func(blob : Blob) : Nat {
            var n = 0;
            var i = 0;
            let bytes = Base.Array.reverse(Base.Blob.toArray(blob));

            for (byte in bytes.vals()) {
                n *= 255;
                n += Base.Nat8.toNat(byte);

                i += 1;
            };

            n;
        };
    };

    public let Nat8 = {
        to_blob = func(n : Nat8) : Blob { Base.Blob.fromArray([n]) };
        from_blob = func(blob : Blob) : Nat8 { Base.Blob.toArray(blob)[0] };
    };

    public let Nat16 = {
        to_blob = func(n : Nat16) : Blob {
            Base.Blob.fromArray([
                Base.Nat8.fromNat16(n & 0xff),
                Base.Nat8.fromNat16(n >> 8),
            ])
        };
        from_blob = func(blob : Blob) : Nat16 {
            let bytes = Base.Blob.toArray(blob);

            let n16 = Base.Nat16.fromNat8(bytes[1] << 8) 
                | Base.Nat16.fromNat8(bytes[0]);
        };
    };

    public let Nat32 = {
        to_blob = func(n : Nat32) : Blob{
            Base.Blob.fromArray([
                Base.Nat8.fromNat(Base.Nat32.toNat(n & 0xff)),
                Base.Nat8.fromNat(Base.Nat32.toNat((n >> 8) & 0xff)),
                Base.Nat8.fromNat(Base.Nat32.toNat((n >> 16) & 0xff)),
                Base.Nat8.fromNat(Base.Nat32.toNat(n >> 24)),
            ])
        };
        from_blob = func(blob : Blob) : Nat32 {
            let bytes = Base.Blob.toArray(blob);

            let n32 = Base.Nat32.fromNat(Base.Nat8.toNat(bytes[3] << 24))
                | Base.Nat32.fromNat(Base.Nat8.toNat(bytes[2] << 16))
                | Base.Nat32.fromNat(Base.Nat8.toNat(bytes[1] << 8))
                | Base.Nat32.fromNat(Base.Nat8.toNat(bytes[0]));
        };
    };

    public let Nat64 = {
        to_blob = func(n : Nat64) : Blob {
            Base.Blob.fromArray([
                Base.Nat8.fromNat(Base.Nat64.toNat(n & 0xff)),
                Base.Nat8.fromNat(Base.Nat64.toNat((n >> 8) & 0xff)),
                Base.Nat8.fromNat(Base.Nat64.toNat((n >> 16) & 0xff)),
                Base.Nat8.fromNat(Base.Nat64.toNat((n >> 24) & 0xff)),
                Base.Nat8.fromNat(Base.Nat64.toNat((n >> 32) & 0xff)),
                Base.Nat8.fromNat(Base.Nat64.toNat((n >> 40) & 0xff)),
                Base.Nat8.fromNat(Base.Nat64.toNat((n >> 48) & 0xff)),
                Base.Nat8.fromNat(Base.Nat64.toNat(n >> 56)),
            ])
        };
        from_blob = func(blob : Blob) : Nat64 {
            let bytes = Base.Blob.toArray(blob);

            let n64 = Base.Nat64.fromNat(Base.Nat8.toNat(bytes[7] << 56))
                | Base.Nat64.fromNat(Base.Nat8.toNat(bytes[6] << 48))
                | Base.Nat64.fromNat(Base.Nat8.toNat(bytes[5] << 40))
                | Base.Nat64.fromNat(Base.Nat8.toNat(bytes[4] << 32))
                | Base.Nat64.fromNat(Base.Nat8.toNat(bytes[3] << 24))
                | Base.Nat64.fromNat(Base.Nat8.toNat(bytes[2] << 16))
                | Base.Nat64.fromNat(Base.Nat8.toNat(bytes[1] << 8))
                | Base.Nat64.fromNat(Base.Nat8.toNat(bytes[0]));    
        };
    };

    public let Blob = {
        to_blob = func(b : Blob) : Blob = b;
        from_blob = func(blob : Blob) : Blob = blob;
    };

    public let Bool = {
        to_blob = func(b : Bool) : Blob = Base.Blob.fromArray([if (b) 1 else 0]);
        from_blob = func(blob : Blob) : Bool {
            blob == Base.Blob.fromArray([1]);
        };
    };

    public let Text = {
        to_blob = func(t : Text) : Blob = TextModule.encodeUtf8(t);
        from_blob = func(blob : Blob) : Text {
            let ?text = TextModule.decodeUtf8(blob) else Debug.trap("from_blob() on Blobify.Text failed to decodeUtf8");
            text;
        };
    };

    public let Principal = {
        to_blob = func(p : Principal) : Blob { Base.Principal.toBlob(p) };
        from_blob = func(blob : Blob) : Principal { Base.Principal.fromBlob(blob) };
    };


    public let t_blob = Text;
    public let b_blob = Blob;
    public let n_blob = Nat;
    public let n8_blob = Nat8;
    public let n16_blob = Nat16;
    public let n32_blob = Nat32;
    public let n64_blob = Nat64;
    public let p_blob = Principal;
};
