# MemoryBTree/BTreeUtils

## Type `BTreeUtils`
``` motoko no-repl
type BTreeUtils<K, V> = { key : Blobify<K>; val : Blobify<V>; cmp : MemoryCmp<K> }
```


## Type `SingleUtil`
``` motoko no-repl
type SingleUtil<K> = { blobify : Blobify<K>; cmp : MemoryCmp<K> }
```


## Function `createUtils`
``` motoko no-repl
func createUtils<K, V>(key : SingleUtil<K>, val : SingleUtil<V>) : BTreeUtils<K, V>
```


## Module `BigEndian`

``` motoko no-repl
module BigEndian
```


### Value `Nat`
``` motoko no-repl
let Nat : SingleUtil<Nat>
```



### Value `Nat8`
``` motoko no-repl
let Nat8 : SingleUtil<Nat8>
```



### Value `Nat16`
``` motoko no-repl
let Nat16 : SingleUtil<Nat16>
```



### Value `Nat32`
``` motoko no-repl
let Nat32 : SingleUtil<Nat32>
```



### Value `Nat64`
``` motoko no-repl
let Nat64 : SingleUtil<Nat64>
```


## Value `Nat`
``` motoko no-repl
let Nat : SingleUtil<Nat>
```


## Value `Nat8`
``` motoko no-repl
let Nat8 : SingleUtil<Nat8>
```


## Value `Nat16`
``` motoko no-repl
let Nat16 : SingleUtil<Nat16>
```


## Value `Nat32`
``` motoko no-repl
let Nat32 : SingleUtil<Nat32>
```


## Value `Nat64`
``` motoko no-repl
let Nat64 : SingleUtil<Nat64>
```


## Value `Blob`
``` motoko no-repl
let Blob : SingleUtil<Blob>
```


## Value `Bool`
``` motoko no-repl
let Bool : SingleUtil<Bool>
```


## Value `Text`
``` motoko no-repl
let Text : SingleUtil<Text>
```


## Value `Char`
``` motoko no-repl
let Char : SingleUtil<Char>
```


## Value `Principal`
``` motoko no-repl
let Principal : SingleUtil<Principal>
```

