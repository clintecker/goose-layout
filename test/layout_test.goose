// Every field type in both byte orders, a nested struct, a read that does
// not fit, size, the cursor forms, and each write read back. Run from the
// package root: goose run test/layout_test.goose
import std;
import binary;
import layout from "..";

struct Inner { b: u8, s: i16 }
struct All { u1: u8, s1: i8, u2: u16, s2: i16, u4: u32, s4: i32, u8_: u64, s8: i64, inner: Inner }

fn bytes(xs: i64[:]) -> u8[>..] {
    var out: u8[>..] = [];
    for x in xs { out.push(x as u8); }
    return out;
}

fn zero() -> All {
    All { u1: 0, s1: 0, u2: 0, s2: 0, u4: 0, s4: 0, u8_: 0, s8: 0, inner: Inner { b: 0, s: 0 } }
}

fn same(a: All&, b: All&) -> bool {
    a.u1 == b.u1 && a.s1 == b.s1 && a.u2 == b.u2 && a.s2 == b.s2 && a.u4 == b.u4 && a.s4 == b.s4
        && a.u8_ == b.u8_ && a.s8 == b.s8 && a.inner.b == b.inner.b && a.inner.s == b.inner.s
}

fn main() {
    // 1 + 1 + 2 + 2 + 4 + 4 + 8 + 8 + (1 + 2) bytes.
    var a = zero();
    assert(layout::size(a) == 33);

    let data = bytes([0xfe, 0xff, 0x12, 0x34, 0xff, 0xfe, 0x01, 0x02, 0x03, 0x04, 0x80, 0x00, 0x00, 0x00,
                      0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xfe,
                      0x09, 0x00, 0x2a]);
    assert(layout::read_be(data, 0, a));
    assert(a.u1 == 0xfe && a.s1 == -1 && a.u2 == 0x1234 && a.s2 == -2 && a.u4 == 0x01020304);
    assert(a.s4 == -2147483648 && a.u8_ == 0x0102030405060708 && a.s8 == -2 && a.inner.b == 9 && a.inner.s == 42);

    var l = zero();
    assert(layout::read_le(data, 0, l));
    assert(l.u2 == 0x3412 && l.s2 == -257 && l.u4 == 0x04030201 && l.s4 == 128);
    assert(l.u8_ == 0x0807060504030201 && l.s8 == -72057594037927937 && l.inner.s == 0x2a00);

    // Each write gives back the bytes it was read from.
    var be: u8[>..] = [];
    layout::append_be(be, a);
    assert(be == data);
    var le: u8[>..] = [];
    layout::append_le(le, l);
    assert(le == data);

    // One byte short, or past the end: false, and the value as it was.
    var c = zero();
    c.u1 = 7;
    assert(!layout::read_be(data[..32], 0, c));
    assert(!layout::read_be(data, 1, c));
    assert(!layout::read_be(data, -1, c));
    assert(c.u1 == 7 && c.u2 == 0);

    // The cursor moves past a value that fits, and stays when one does not.
    var r = binary::reader(data);
    var inner = Inner { b: 0, s: 0 };
    assert(layout::read_be(r, inner) && r.pos == 3 && inner.b == 0xfe && inner.s == -238);
    assert(layout::read_le(r, inner) && r.pos == 6 && inner.b == 0x34 && inner.s == -257);
    var big = zero();
    assert(!layout::read_be(r, big) && r.pos == 6);

    var back = zero();
    assert(layout::read_be(be, 0, back) && same(back, a));
    print("layout_test: ok");
}
