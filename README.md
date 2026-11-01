# clintecker/goose-layout

Fixed binary headers for [Goose](https://github.com/aardappel/goose), read into a struct and written from one, in either byte order. You declare the header as a struct; the package reads its fields in declaration order. Nothing is allocated, and a read either fills every field or none.

```goose
import layout from "clintecker/goose-layout@v1";

// A Mach-O fat binary's arch entry: five big-endian u32.
struct FatArch { cpu: u32, subtype: u32, offset: u32, size: u32, align: u32 }

var a = FatArch { cpu: 0, subtype: 0, offset: 0, size: 0, align: 0 };
if !layout::read_be(data, 8, a) { ... }    // false, and a unchanged, when 20 bytes do not fit at 8
```

## Functions

| Function | What it does |
|---|---|
| `read_le(data, at, x) -> bool`, `read_be(...)` | fills the struct `x` from `data` at `at`, little- or big-endian; false, with `x` unchanged, when it does not fit |
| `read_le(r, x) -> bool`, `read_be(r, x)` | the same on a `binary::Reader`, whose `pos` moves past `x` only when it fits |
| `append_le(out, x)`, `append_be(out, x)` | appends `x`'s fields to a `u8[>..]`, in the same layout |
| `size(x) -> i64` | the bytes `x` takes: the sum of its fields' |

A field is `u8`, `u16`, `u32` or `u64`, `i8` to `i64`, or a struct of these, nested to any depth. A magic number is a `u32` or `u64` field: PNG's chunk type `IHDR` read big-endian is `0x49484452`. There is no padding: fields follow each other, as they do on disk.

## How

`const for <N, A> in fields<T>` (spec §6.5) expands into one statement per field at compile time, and an overload per integer type does each field's shifts, so a read compiles to what a hand-written one would be. Go's `binary.Read` does the same by reflection at run time, Rust's `binrw` with derive macros, and Python's `struct.unpack(">IIBB", b)` with a format string nothing checks against the variables.

## Limits

- No floats: Goose v2026.3 has no way to a float's bits.
- No fixed arrays (`u8[N]`), and no field types of your own. The overload that walks a nested struct is generic, and Goose ranks a generic exact match above the array-to-slice coercion a `u8[:]` overload would need (spec §7.1); it has no size parameters, and a package's calls do not see a program's overloads.
- A layout that depends on a field, such as ELF's 32- and 64-bit headers, is a struct per variant, chosen by the program.

## Tests

From the package root: `goose run test/layout_test.goose`. It reads a 33-byte record of every field type in both byte orders, writes each back and compares the bytes, reads past the end and short, and moves a cursor.

MIT licence (LICENSE).
