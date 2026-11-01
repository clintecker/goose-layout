// Fixed binary headers read into a struct, and written from one, field by
// field in declaration order, in a stated byte order. A field is an integer
// (u8 to u64, i8 to i64) or a struct of them, nested to any depth. `const
// for` (spec §6.5) expands the fields at compile time, so a read is the
// shifts a hand-written one would be: no format string, no reflection,
// nothing allocated. A read either fills every field or none.
namespace layout;
import std;
import binary;

// --- one integer -------------------------------------------------------------------

// The value of b's bytes; big: the most significant byte first.
fn join(big: bool, b: const u8[:]) -> u64 {
    var v: u64 = 0;
    for c, k in b {
        if big { v = v << 8 | c; } else { v |= c as u64 << (8 * k) as u64; }
    }
    return v;
}

// v's low n bytes, appended; big: the most significant byte first.
fn split(big: bool, out: u8[>..]&, v: u64, n: i64) {
    for k in n {
        let shift = if big { 8 * (n - 1 - k) } else { 8 * k };
        out.push(((v >> (shift as u64)) & 0xff) as u8);
    }
}

// --- each field type: its size, its read and its write --------------------------------

fn size(x: u8) -> i64 { 1 }
fn size(x: i8) -> i64 { 1 }
fn size(x: u16) -> i64 { 2 }
fn size(x: i16) -> i64 { 2 }
fn size(x: u32) -> i64 { 4 }
fn size(x: i32) -> i64 { 4 }
fn size(x: u64) -> i64 { 8 }
fn size(x: i64) -> i64 { 8 }

// The bytes a struct takes: the sum of its fields'.
fn size<T>(x: T&) -> i64 {
    var n = 0;
    const for <N, A> in fields<T> { n += size(x.A); }
    return n;
}

// Reads at `at`, which the caller has checked, and moves it past the field.
fn get(big: bool, b: const u8[:], at: i64&, x: u8&) { x = b[at]; at += 1; }
fn get(big: bool, b: const u8[:], at: i64&, x: i8&) { x = b[at] as! i8; at += 1; }
fn get(big: bool, b: const u8[:], at: i64&, x: u16&) { x = join(big, b[at..at + 2]) as! u16; at += 2; }
fn get(big: bool, b: const u8[:], at: i64&, x: i16&) { x = join(big, b[at..at + 2]) as! i16; at += 2; }
fn get(big: bool, b: const u8[:], at: i64&, x: u32&) { x = join(big, b[at..at + 4]) as! u32; at += 4; }
fn get(big: bool, b: const u8[:], at: i64&, x: i32&) { x = join(big, b[at..at + 4]) as! i32; at += 4; }
fn get(big: bool, b: const u8[:], at: i64&, x: u64&) { x = join(big, b[at..at + 8]); at += 8; }
fn get(big: bool, b: const u8[:], at: i64&, x: i64&) { x = join(big, b[at..at + 8]) as! i64; at += 8; }

fn get<T>(big: bool, b: const u8[:], at: i64&, x: T&) {
    const for <N, A> in fields<T> { get(big, b, at, x.A); }
}

fn put(big: bool, out: u8[>..]&, x: u8) { out.push(x); }
fn put(big: bool, out: u8[>..]&, x: i8) { out.push(x as! u8); }
fn put(big: bool, out: u8[>..]&, x: u16) { split(big, out, x, 2); }
fn put(big: bool, out: u8[>..]&, x: i16) { split(big, out, x as! u64, 2); }
fn put(big: bool, out: u8[>..]&, x: u32) { split(big, out, x, 4); }
fn put(big: bool, out: u8[>..]&, x: i32) { split(big, out, x as! u64, 4); }
fn put(big: bool, out: u8[>..]&, x: u64) { split(big, out, x, 8); }
fn put(big: bool, out: u8[>..]&, x: i64) { split(big, out, x as! u64, 8); }

fn put<T>(big: bool, out: u8[>..]&, x: T&) {
    const for <N, A> in fields<T> { put(big, out, x.A); }
}

// --- the interface ---------------------------------------------------------------------

// Fills x from data at `at`; false, and x unchanged, when it does not fit.
fn read<T>(big: bool, data: const u8[:], at: i64, x: T&) -> bool {
    guard binary::range_ok(data, at, size(x)) else { return false; }
    var p = at;
    get(big, data, p, x);
    return true;
}

fn read_le<T>(data: const u8[:], at: i64, x: T&) -> bool { read(false, data, at, x) }
fn read_be<T>(data: const u8[:], at: i64, x: T&) -> bool { read(true, data, at, x) }

// On a cursor, which moves past x only when it fits.
fn read_le<T>(r: binary::Reader&, x: T&) -> bool { step(r, read(false, r.data, r.pos, x), x) }
fn read_be<T>(r: binary::Reader&, x: T&) -> bool { step(r, read(true, r.data, r.pos, x), x) }

fn step<T>(r: binary::Reader&, ok: bool, x: T&) -> bool {
    if ok { r.pos += size(x); }
    return ok;
}

fn append_le<T>(out: u8[>..]&, x: T&) { put(false, out, x); }
fn append_be<T>(out: u8[>..]&, x: T&) { put(true, out, x); }
