import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Buffer "mo:base/Buffer";

import T "Types";

module {

    public func shift_by<A>(arr : [var ?A], start : Nat, end : Nat, shift : Int) {
        if (shift == 0) return;

        if (shift > 0) {
            var i = end; // exclusive
            while (i > start) {
                arr[Int.abs(shift + i - 1)] := arr[i - 1];
                arr[i - 1] := null;
                i -= 1;
            };
            return;
        };

        var i = start;
        while (i < end) {
            arr[Int.abs(shift + i)] := arr[i];
            arr[i] := null;
            i += 1;
        };

    };

    public func count<A>(arr : [var ?A]) : Nat {
        var cnt = 0;

        while (cnt < arr.size()) {
            switch (arr[cnt]) {
                case (?val) {};
                case (_) return cnt;
            };

            cnt += 1;
        };
        
        return cnt;
    };

    public func extract<T>(arr : [var ?T], index : Nat) : ?T {
        let tmp = arr[index];
        arr[index] := null;
        tmp;
    };
    
    public func insert<A>(arr : [var ?A], index : Nat, item : ?A, size : Nat) {
        var i = size;
        while (i > index) {
            arr[i] := arr[i - 1];
            i -= 1;
        };

        arr[index] := item;
    };

    public func remove<A>(arr : [var ?A], index : Nat, size : Nat) : ?A {
        if (size == 0) return null;

        var i = index;
        let item = arr[i];

        while (i < (size - 1 : Nat)) {
            arr[i] := arr[i + 1];
            i += 1;
        };

        arr[i] := null;

        item;
    };

    // removeIf is a function that removes an element from an array if the predicate is true
    // it returns the size of the array after the removal
    public func removeIf<A>(arr : [var ?A], size : Nat, should_remove: (val: A, index: Nat) -> Bool) : Nat {
        if (size == 0) return size;

        var i = 0;
        var removed = 0;

        while (i < size){
            let ?val = arr[i] else Debug.trap("ArrayMut.removeIf(): encountered null value at index (" # debug_show i #"). Is count (" # debug_show size # ") valid?");
            if (should_remove(val, i)){
                removed += 1;
                arr[i] := null;
            };
            i += 1;
        };

        var read = 0;
        var write = 0;

        while (read < size){
            switch (arr[read]){
                case (?val) {
                    arr[read] := null;
                    arr[write] := ?val;
                    write += 1;
                };
                case (_) {};
            };

            read += 1;
        };
        
        Debug.print("count: " # debug_show count(arr));
        assert count(arr) == (size - removed : Nat);
        size - removed;
    };

    public func swap<A>(arr : [var ?A], i : Nat, j : Nat) {
        let temp = arr[i];
        arr[i] := arr[j];
        arr[j] := temp;
    };

    public func index_of<A>(arr : [var ?A], size : Nat, is_equal: (A, A) -> Bool, item : A) : ?Nat {
        var i = 0;
        var found = false;

        label while_loop while (i < size) {
            switch(arr[i]){
                case (?val) found := is_equal(val, item);
                case (_) Debug.trap("ArrayMut.index_of(): encountered null value in heap. Is count (" # debug_show size # ") valid?");
            };

            if (found) break while_loop;
            i += 1;
        };

        if (not found) return null;

        return ?i;
    };

    // public func binary_search_blob_seq<B, A>(arr : [var ?A], cmp : T.MultiCmpFn<B, A>, search_key : B, arr_len : Nat) : Int {
    //     if (arr_len == 0) return -1; // should insert at index Int.abs(i + 1)
    //     var l = 0;

    //     // arr_len will always be between 4 and 512
    //     var r = arr_len - 1 : Nat;

    //     while (l < r) {
    //         let mid = (l + r) / 2;

    //         let ?val = arr[mid] else Debug.trap("1. binary_search_blob_seq: accessed a null value");

    //         let result = cmp(search_key, val);
    //         if (result == -1) {
    //             r := mid;

    //         } else if (result == 1) {
    //             l := mid + 1;
    //         } else {
    //             return mid;
    //         };

    //     };

    //     let insertion = l;

    //     // Check if the insertion point is valid
    //     // return the insertion point but negative and subtracting 1 indicating that the key was not found
    //     // such that the insertion index for the key is Int.abs(insertion) - 1
    //     // [0,  1,  2]
    //     //  |   |   |
    //     // -1, -2, -3
    //     switch (arr[insertion]) {
    //         case (?val) {
    //             let result = cmp(search_key, val);

    //             if (result == 0) insertion
    //             else if (result == -1) -(insertion + 1)
    //             else  -(insertion + 2);
    //         };
    //         case (_) {
    //             Debug.print("insertion = " # debug_show insertion);
    //             Debug.print("arr_len = " # debug_show arr_len);
    //             Debug.print(
    //                 "arr = " # debug_show Array.map(
    //                     Array.freeze(arr),
    //                     func(opt_val : ?A) : Text {
    //                         switch (opt_val) {
    //                             case (?val) "1";
    //                             case (_) "0";
    //                         };
    //                     },
    //                 )
    //             );
    //             Debug.trap("2. binary_search_blob_seq: accessed a null value");
    //         };
    //     };
    // };

    public func to_buffer<A>(arr: [var ?A]) : Buffer.Buffer<A>{
        let buffer = Buffer.Buffer<A>(8);
        var i = 0;

        label loop1 while (i < arr.size()) {
            switch(arr[i]){
                case (?val) buffer.add(val);
                case (_) return buffer;
            };

            i += 1;
        };

        buffer
    };
    
};
