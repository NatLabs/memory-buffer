// @testmode wasi
import { test; suite } "mo:test";
import MemoryBuffer "../../src/MemoryBuffer/Base";
import VersionedMemoryBuffer "../../src/MemoryBuffer/Versioned";
import Migrations "../../src/MemoryBuffer/Migrations";
import Blobify "../../src/Blobify";

suite(
    "MemoryBuffer Migration Tests", 
    func (){
        test("deploys current version", func (){
            let vs_memory_region = VersionedMemoryBuffer.new();
            ignore Migrations.getCurrentVersion(vs_memory_region); // should not trap

            let memory_region = MemoryBuffer.new();
            let version = MemoryBuffer.toVersioned(memory_region);
            ignore Migrations.getCurrentVersion(version); // should not trap
        });
    }
)