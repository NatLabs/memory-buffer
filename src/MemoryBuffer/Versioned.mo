/// Versioned Module for the MemoryBuffer
///
/// This module provides a this wrapper around the base MemoryBuffer module that add versioning for easy
/// upgrades to future versions without breaking compatibility with existing code.

import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Order "mo:base/Order";

import MemoryRegion "mo:memory-region/MemoryRegion";
import RevIter "mo:itertools/RevIter";

import Blobify "../Blobify";
import MemoryBuffer "Base";
import Migrations "Migrations";
import MemoryCmp "../MemoryCmp";

module VersionedMemoryBuffer {
    type Iter<A> = Iter.Iter<A>;
    type RevIter<A> = RevIter.RevIter<A>;
    type Result<A, B> = Result.Result<A, B>;
    type MemoryRegion = MemoryRegion.MemoryRegion;

    type MemoryRegionV0 = MemoryRegion.MemoryRegionV0;
    type MemoryRegionV1 = MemoryRegion.MemoryRegionV1;

    type Order = Order.Order;

    public type Blobify<A> = Blobify.Blobify<A>;
    public type MemoryBuffer<A> = Migrations.MemoryBuffer<A>;
    public type VersionedMemoryBuffer<A> = Migrations.VersionedMemoryBuffer<A>;

    public func new<A>() : VersionedMemoryBuffer<A> {
        return MemoryBuffer.toVersioned(MemoryBuffer.new());
    };

    public func upgrade<A>(self : VersionedMemoryBuffer<A>) : VersionedMemoryBuffer<A> {
        Migrations.upgrade(self);
    };

    public func verify<A>(self : VersionedMemoryBuffer<A>) : Result<(), Text> {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.verify(state);
    };

    public func init<A>(self : Blobify<A>, size : Nat, val : A) : VersionedMemoryBuffer<A> {
        return MemoryBuffer.toVersioned(MemoryBuffer.init(self, size, val));
    };

    public func tabulate<A>(blobify : Blobify<A>, size : Nat, fn : (i : Nat) -> A) : VersionedMemoryBuffer<A> {
        return MemoryBuffer.toVersioned(MemoryBuffer.tabulate(blobify, size, fn));
    };

    public func fromArray<A>(blobify : Blobify<A>, arr : [A]) : VersionedMemoryBuffer<A> {
        return MemoryBuffer.toVersioned(MemoryBuffer.fromArray(blobify, arr));
    };

    public func fromIter<A>(blobify : Blobify<A>, iter : Iter<A>) : VersionedMemoryBuffer<A> {
        return MemoryBuffer.toVersioned(MemoryBuffer.fromIter(blobify, iter));
    };

    public func size<A>(self : VersionedMemoryBuffer<A>) : Nat {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.size(state);
    };

    public func bytes<A>(self : VersionedMemoryBuffer<A>) : Nat {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.bytes(state);
    };

    public func metadataBytes<A>(self : VersionedMemoryBuffer<A>) : Nat {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.metadataBytes(state);
    };

    public func totalBytes<A>(self : VersionedMemoryBuffer<A>) : Nat {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.totalBytes(state);
    };

    public func capacity<A>(self : VersionedMemoryBuffer<A>) : Nat {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.capacity(state);
    };

    public func put<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, index : Nat, value : A) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.put(state, blobify, index, value);
    };

    public func getOpt<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : ?A {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.getOpt(state, blobify, index);
    };

    public func get<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : A {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.get(state, blobify, index);
    };

    public func addFirst<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, value : A) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.addFirst(state, blobify, value);
    };

    public func addLast<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, value : A) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.addLast(state, blobify, value);
    };

    public func addFromIter<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, iter : Iter<A>) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.addFromIter(state, blobify, iter);
    };

    public func addFromArray<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, arr : [A]) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.addFromArray(state, blobify, arr);
    };

    public func add<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, value : A) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.add(state, blobify, value);
    };

    public func append<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, other : VersionedMemoryBuffer<A>) {
        let curr_state = Migrations.getCurrentVersion(self);
        let other_state = Migrations.getCurrentVersion(other);
        MemoryBuffer.append(curr_state, blobify, other_state);
    };

    public func vals<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>) : RevIter<A> {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.vals(state, blobify);
    };

    public func items<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>) : RevIter<(index : Nat, value : A)> {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.items(state, blobify);
    };

    public func blobs<A>(self : VersionedMemoryBuffer<A>) : RevIter<Blob> {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.blobs(state);
    };

    public func pointers<A>(self : VersionedMemoryBuffer<A>) : RevIter<Nat> {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.pointers(state);
    };

    public func blocks<A>(self: VersionedMemoryBuffer<A>) : RevIter<(Nat, Nat)> {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.blocks(state);
    };

    public func remove<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : A {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.remove(state, blobify, index);
    };

    public func removeFirst<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>) : ?A {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.removeFirst(state, blobify);
    };

    public func removeLast<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>) : ?A {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.removeLast(state, blobify);
    };

    public func swap<A>(self : VersionedMemoryBuffer<A>, index_a : Nat, index_b : Nat) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.swap(state, index_a, index_b);
    };

    public func swapRemove<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, index : Nat) : A {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.swapRemove(state, blobify, index);
    };

    public func reverse<A>(self : VersionedMemoryBuffer<A>) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.reverse(state);
    };

    public func clear<A>(self : VersionedMemoryBuffer<A>) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.clear(state);
    };

    public func clone<A>(self : VersionedMemoryBuffer<A>) : VersionedMemoryBuffer<A> {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.toVersioned(MemoryBuffer.clone(state));
    };

    public func insert<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, index : Nat, value : A) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.insert(state, blobify, index, value);
    };

    public func sortUnstable<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, cmp : MemoryCmp.MemoryCmp<A> ) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.sortUnstable(state, blobify, cmp);
    };

    public func shuffle<A>(self : VersionedMemoryBuffer<A>) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.shuffle(state);
    };

    public func indexOf<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, equal: (A, A) -> Bool, value : A) : ?Nat {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.indexOf(state, blobify, equal, value);
    };

    public func lastIndexOf<A>(self: VersionedMemoryBuffer<A>, blobify: Blobify<A>, equal: (A, A) -> Bool, value: A) : ?Nat {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.lastIndexOf(state, blobify, equal, value);
    };

    public func contains<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>, equal: (A, A) -> Bool, value : A) : Bool {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.contains(state, blobify, equal, value);
    };

    public func isEmpty<A>(self : VersionedMemoryBuffer<A>) : Bool {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.isEmpty(state);
    };

    public func first<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>) : A {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.first(state, blobify);
    };

    public func last<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>) : A {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.last(state, blobify);
    };

    public func peekFirst<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>) : ?A {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.peekFirst(state, blobify);
    };

    public func peekLast<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>) : ?A {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.peekLast(state, blobify);
    };

    public func toArray<A>(self : VersionedMemoryBuffer<A>, blobify : Blobify<A>) : [A] {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.toArray(state, blobify);
    };

};
