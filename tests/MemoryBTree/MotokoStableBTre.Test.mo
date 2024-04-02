// @testmode wasi
import { test; suite } "mo:test";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Nat32 "mo:base/Nat32";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Region "mo:base/Region";

import LruCache "mo:lru-cache";
import Fuzz "mo:fuzz";
import Itertools "mo:itertools/Iter";
import Map "mo:map/Map";

import MotokoStableBTree "mo:MotokoStableBTree/BTree";
import BTreeMap "mo:MotokoStableBTree/modules/btreemap";
import BTreeMapMemory "mo:MotokoStableBTree/modules/memory";

type Buffer<A> = Buffer.Buffer<A>;
type Iter<A> = Iter.Iter<A>;

        let { nconv; tconv } = MotokoStableBTree;
        let tconv_20 = tconv(20);
        let nconv_32 = nconv(32);

        let stable_btree = BTreeMap.new<Nat, Nat>(BTreeMapMemory.RegionMemory(Region.new()), nconv_32, nconv_32);

let { nhash } = Map;
let fuzz = Fuzz.fromSeed(0xdeadbeef);

let limit = 10_000;

let nat_gen_iter : Iter<Nat> = {
    next = func() : ?Nat = ?fuzz.nat.randomRange(1, limit * 10);
};
let unique_iter = Itertools.unique<Nat>(nat_gen_iter, Nat32.fromNat, Nat.equal);
let random = Itertools.toBuffer<Nat>(Itertools.take(unique_iter, limit));
let sorted = Buffer.clone(random);
sorted.sort(Nat.compare);

suite(
    "MotokoStableBTree",
    func() {
        test(
            "insert ",
            func() {
                for (n in random.vals()){
                    ignore stable_btree.insert(n, nconv_32, n, nconv_32);
                };

                for (n in random.vals()){
                    assert ?n == stable_btree.get(n, nconv_32, nconv_32);
                };
            },
        );

        test("entries", func(){
            var i = 0;
            for ((n, (k, v)) in Itertools.zip(sorted.vals(), stable_btree.iter(nconv_32, nconv_32))){
                i+=1;
                if (not (n == k and n == v)){
                    Debug.print("mismatch " # debug_show(n, (k, v)));
                    assert false;
                };
            };

            assert i == random.size();
        });
    },
);
