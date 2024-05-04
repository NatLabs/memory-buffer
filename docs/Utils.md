# Utils

## Function `sized_iter_to_array`
``` motoko no-repl
func sized_iter_to_array<A>(iter : Iter<A>, size : Nat) : [A]
```


## Function `unwrap`
``` motoko no-repl
func unwrap<T>(optional : ?T, trap_msg : Text) : T
```


## Function `shuffle_buffer`
``` motoko no-repl
func shuffle_buffer<A>(fuzz : Fuzz.Fuzzer, buffer : Buffer.Buffer<A>)
```


## Function `send_error`
``` motoko no-repl
func send_error<OldOk, NewOk, Error>(res : Result<OldOk, Error>) : Result<NewOk, Error>
```


## Function `nat_to_blob`
``` motoko no-repl
func nat_to_blob(num : Nat, nbytes : Nat) : Blob
```


## Function `blob_to_nat`
``` motoko no-repl
func blob_to_nat(blob : Blob) : Nat
```


## Function `byte_iter_to_nat`
``` motoko no-repl
func byte_iter_to_nat(iter : Iter<Nat8>) : Nat
```

