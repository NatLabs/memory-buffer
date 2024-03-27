// @testmode wasi
import { test; suite } "mo:test";
import Debug "mo:base/Debug";
import MemoryBTree "../../src/MemoryBTree/Base";
import VersionedMemoryBuffer "../../src/VersionedMemoryBuffer";
import Migrations "../../src/Migrations";
import Blobify "../../src/Blobify";
import MemoryCmp "../../src/MemoryCmp";

type MemoryUtils<K, V> = MemoryBTree.MemoryUtils<K, V>;

suite(
    "MemoryBTree", 
    func (){
        test("new()", func (){
            let btree = MemoryBTree.new(?4);
            assert MemoryBTree.size(btree) == 0;

            let mem_utils : MemoryUtils<Nat, Nat> = (
                Blobify.Nat,
                Blobify.Nat,
                MemoryCmp.Default
            );

            ignore MemoryBTree.insert(btree, mem_utils, 1, 1);
            ignore MemoryBTree.insert(btree, mem_utils, 2, 2);
            ignore MemoryBTree.insert(btree, mem_utils, 0, 0);
            ignore MemoryBTree.insert(btree, mem_utils, 3, 3);
            
            assert MemoryBTree.size(btree) == 4;

            ignore MemoryBTree.insert(btree, mem_utils, 4, 4);

            // Debug.print("btree: " # debug_show btree);

        });
    }
)