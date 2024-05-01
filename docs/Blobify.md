# Blobify
Blobify is a module that provides a generic interface for converting
values to and from blobs. It is intended to be used for serializing
and deserializing values that will be stored in persistent stable memory.

The Blobify module provides a default implementation for the following
types:
- Nat
- Nat8
- Nat16
- Nat32
- Nat64
- Blob
- Bool
- Text
- Principal

## Type `Blobify`
``` motoko no-repl
type Blobify<A> = { to_blob : (A) -> Blob; from_blob : (Blob) -> A }
```


## Module `BigEndian`

``` motoko no-repl
module BigEndian
```


### Value `Nat`
``` motoko no-repl
let Nat : Blobify<Nat>
```



### Value `Nat8`
``` motoko no-repl
let Nat8 : Blobify<Nat8>
```



### Value `Nat16`
``` motoko no-repl
let Nat16 : Blobify<Nat16>
```



### Value `Nat32`
``` motoko no-repl
let Nat32 : Blobify<Nat32>
```



### Value `Nat64`
``` motoko no-repl
let Nat64 : Blobify<Nat64>
```


## Value `Nat8`
``` motoko no-repl
let Nat8 : Blobify<Nat8>
```


## Value `Nat16`
``` motoko no-repl
let Nat16 : Blobify<Nat16>
```


## Value `Nat32`
``` motoko no-repl
let Nat32 : Blobify<Nat32>
```


## Value `Nat64`
``` motoko no-repl
let Nat64 : Blobify<Nat64>
```


## Value `Nat`
``` motoko no-repl
let Nat : Blobify<Nat>
```


## Value `Blob`
``` motoko no-repl
let Blob : Blobify<Blob>
```


## Value `Bool`
``` motoko no-repl
let Bool : Blobify<Bool>
```


## Value `Char`
``` motoko no-repl
let Char : Blobify<Char>
```


## Value `Text`
``` motoko no-repl
let Text : Blobify<Text>
```


## Value `Principal`
``` motoko no-repl
let Principal : Blobify<Principal>
```

