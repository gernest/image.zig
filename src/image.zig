const geom = @import("geom.zig");
const std = @import("std");
const testing = std.testing;
const print = std.debug.print;
const meta = std.meta;

const Rectangle = geom.Rectangle;
const Point = geom.Point;

/// Color can convert itself to alpha-premultiplied 16-bits per channel RGBA.
/// The conversion may be lossy.
pub const Color = union(enum) {
    rgba: RGBA,
    rgba64: RGBA64,
    nrgba: NRGBA,
    nrgba64: NRGBA64,
    alpha: Alpha,
    alpha16: Alpha16,
    gray: Gray,
    gray16: Gray16,
    yCbCr: YCbCr,
    nYCbCrA: NYCbCrA,
    cMYK: CMYK,

    pub fn toValue(self: Color) Value {
        return switch (self) {
            .rgba => |i| i.toValue(),
            .rgba64 => |i| i.toValue(),
            .nrgba => |i| i.toValue(),
            .nrgba64 => |i| i.toValue(),
            .alpha => |i| i.toValue(),
            .alpha16 => |i| i.toValue(),
            .gray => |i| i.toValue(),
            .gray16 => |i| i.toValue(),
            .yCbCr => |i| i.toValue(),
            .nYCbCrA => |i| i.toValue(),
            .cMYK => |i| i.toValue(),
        };
    }

    pub const Value = struct {
        r: u32 = 0,
        g: u32 = 0,
        b: u32 = 0,
        a: u32 = 0,

        pub fn eq(self: Value, n: Value) bool {
            return self.r == n.r and self.g == n.g and self.b == n.b and self.a == n.a;
        }
    };

    pub const Model = struct {
        convert: fn (c: Color) Color,

        pub fn rgbaModel(m: Color) Color {
            return switch (m) {
                .rgba => m,
                else => {
                    const c = m.toValue();
                    const model = RGBA{
                        .r = @truncate(u8, c.r >> 8),
                        .g = @truncate(u8, c.g >> 8),
                        .b = @truncate(u8, c.b >> 8),
                        .a = @truncate(u8, c.a >> 8),
                    };
                    return Color{ .rgba = model };
                },
            };
        }

        pub fn rgba64Model(m: Color) Color {
            return switch (m) {
                .rgba64 => m,
                else => {
                    const c = m.toValue();
                    const model = RGBA64{
                        .r = @truncate(u16, c.r),
                        .g = @truncate(u16, c.g),
                        .b = @truncate(u16, c.b),
                        .a = @truncate(u16, c.a),
                    };
                    return Color{ .rgba64 = model };
                },
            };
        }

        pub fn nrgbaModel(m: Color) Color {
            return switch (m) {
                .nrgba => m,
                else => {
                    const c = m.toValue();
                    if (c.a == 0xffff) {
                        const model = NRGBA{
                            .r = @truncate(u8, c.r >> 8),
                            .g = @truncate(u8, c.g >> 8),
                            .b = @truncate(u8, c.b >> 8),
                            .a = 0xff,
                        };
                        return Color{ .nrgba = model };
                    }
                    if (c.a == 0) {
                        const model = NRGBA{
                            .r = 0,
                            .g = 0,
                            .b = 0,
                            .a = 0,
                        };
                        return Color{ .nrgba = model };
                    }
                    var r = mu(c.r, 0xffff) / c.a;
                    var g = mu(c.g, 0xffff) / c.a;
                    var b = mu(c.b, 0xffff) / c.a;
                    const model = NRGBA{
                        .r = @truncate(u8, r >> 8),
                        .g = @truncate(u8, g >> 8),
                        .b = @truncate(u8, b >> 8),
                        .a = @truncate(u8, c.a >> 8),
                    };
                    return Color{ .nrgba = model };
                },
            };
        }

        pub fn nrgba64Model(m: Color) Color {
            return switch (m) {
                .nrgba64 => m,
                else => {
                    const c = m.toValue();
                    if (c.a == 0xffff) {
                        const model = NRGBA64{
                            .r = @truncate(u16, c.r),
                            .g = @truncate(u16, c.g),
                            .b = @truncate(u16, c.b),
                            .a = 0xffff,
                        };
                        return Color{ .nrgba64 = model };
                    }
                    if (c.a == 0) {
                        const model = NRGBA64{
                            .r = 0,
                            .g = 0,
                            .b = 0,
                            .a = 0,
                        };
                        return Color{ .nrgba64 = model };
                    }
                    var r = mu(c.r, 0xffff) / c.a;
                    var g = mu(c.g, 0xffff) / c.a;
                    var b = mu(c.b, 0xffff) / c.a;
                    const model = NRGBA64{
                        .r = @truncate(u16, r),
                        .g = @truncate(u16, g),
                        .b = @truncate(u16, b),
                        .a = @truncate(u16, c.a),
                    };
                    return Color{ .nrgba64 = model };
                },
            };
        }

        fn mu(a: u32, b: u32) u32 {
            var r: u32 = undefined;
            _ = @mulWithOverflow(u32, a, b, &r);
            return r;
        }

        pub fn alphaModel(m: Color) Color {
            return switch (m) {
                .alpha => m,
                else => {
                    const c = m.toValue();
                    const model = Alpha{ .a = @intCast(u8, c.a >> 8) };
                    return Color{ .alpha = model };
                },
            };
        }

        pub fn alpha16Model(m: Color) Color {
            return switch (m) {
                .alpha16 => m,
                else => {
                    const c = m.toValue();
                    const model = Alpha16{ .a = @intCast(u16, c.a) };
                    return Color{ .alpha16 = model };
                },
            };
        }

        pub fn grayModel(m: Color) Color {
            return switch (m) {
                .gray => m,
                else => {
                    const c = m.toValue();
                    // These coefficients (the fractions 0.299, 0.587 and 0.114) are the same
                    // as those given by the JFIF specification and used by func RGBToYCbCr in
                    // ycbcr.go.
                    //
                    // Note that 19595 + 38470 + 7471 equals 65536.
                    //
                    // The 24 is 16 + 8. The 16 is the same as used in RGBToYCbCr. The 8 is
                    // because the return value is 8 bit color, not 16 bit color.
                    const y = (19595 * c.r + 38470 * c.g + 7471 * c.b + 1 << 15) >> 24;
                    const model = Gray{ .y = @intCast(u8, y) };
                    return Color{ .gray = model };
                },
            };
        }

        pub fn gray16Model(m: Color) Color {
            return switch (m) {
                .gray16 => m,
                else => {
                    const c = m.toValue();
                    // These coefficients (the fractions 0.299, 0.587 and 0.114) are the same
                    // as those given by the JFIF specification and used by func RGBToYCbCr in
                    // ycbcr.go.
                    //
                    // Note that 19595 + 38470 + 7471 equals 65536.
                    const y = (19595 * c.r + 38470 * c.g + 7471 * c.b + 1 << 15) >> 16;
                    const model = Gray16{ .y = @intCast(u16, y) };
                    return Color{ .gray16 = model };
                },
            };
        }

        pub fn yCbCrModel(m: Color) Color {
            return switch (m) {
                .yCbCr => m,
                else => {
                    const v = m.toValue();
                    return Color{
                        .yCbCr = rgbToYCbCr(RGB{
                            .r = @intCast(u8, v.r >> 8),
                            .g = @intCast(u8, v.g >> 8),
                            .b = @intCast(u8, v.b >> 8),
                        }),
                    };
                },
            };
        }

        pub fn nYCbCrAModel(m: Color) Color {
            return switch (m) {
                .yYCbCrA => m,
                .yCbCr => |c| NYCbCrA{
                    .y = c,
                    .a = 0xff,
                },
                else => {
                    var v = m.toValue();
                    if (v.a != 0) {
                        v.r = @divTrunc(v.r * 0xffff, v.a);
                        v.g = @divTrunc(v.g * 0xffff, v.a);
                        v.b = @divTrunc(v.b * 0xffff, v.a);
                    }
                    const y = rgbToYCbCr(
                        @intCast(u8, v.r >> 8),
                        @intCast(u8, v.g >> 8),
                        @intCast(u8, v.b >> 8),
                    );
                },
            };
        }

        pub fn cmykModel(c: Color) Color {
            return switch (c) {
                .cMYK => c,
                else => {
                    const v = c.toValue();
                    return Color{
                        .cMYK = rgbToCMYK(RGB{
                            .r = @truncate(u8, v.r >> 8),
                            .g = @truncate(u8, v.g >> 8),
                            .b = @truncate(u8, v.b >> 8),
                        }),
                    };
                },
            };
        }
    };

    pub const RGBA = struct {
        r: u8 = 0,
        g: u8 = 0,
        b: u8 = 0,
        a: u8 = 0,

        fn toValue(c: RGBA) Value {
            var r: u32 = c.r;
            r |= r << 8;
            var g: u32 = c.g;
            g |= g << 8;
            var b: u32 = c.b;
            b |= b << 8;
            var a: u32 = c.a;
            a |= a << 8;
            return Value{
                .r = r,
                .g = g,
                .b = b,
                .a = a,
            };
        }
    };

    pub const RGBA64 = struct {
        r: u16 = 0,
        g: u16 = 0,
        b: u16 = 0,
        a: u16 = 0,

        fn toValue(c: RGBA64) Value {
            return Value{
                .r = c.r,
                .g = c.g,
                .b = c.b,
                .a = c.a,
            };
        }
    };

    pub const NRGBA = struct {
        r: u8 = 0,
        g: u8 = 0,
        b: u8 = 0,
        a: u8 = 0,

        fn toValue(c: NRGBA) Value {
            var r: u32 = c.r;
            var g: u32 = c.g;
            var b: u32 = c.b;
            var a: u32 = c.a;
            r |= r << 8;
            r *= a;
            r /= 0xff;
            g |= g << 8;
            g *= a;
            g /= 0xff;
            b |= b << 8;
            b *= a;
            b /= 0xff;
            a |= a << 8;
            return Value{
                .r = r,
                .g = g,
                .b = b,
                .a = a,
            };
        }
    };

    pub const NRGBA64 = struct {
        r: u16 = 0,
        g: u16 = 0,
        b: u16 = 0,
        a: u16 = 0,

        fn toValue(c: NRGBA64) Value {
            var r = @intCast(u32, c.r);
            var g = @intCast(u32, c.g);
            var b = @intCast(u32, c.b);
            var a = @intCast(u32, c.a);
            _ = @mulWithOverflow(u32, r, a, &r);
            r /= 0xffff;
            _ = @mulWithOverflow(u32, g, a, &g);
            g /= 0xffff;
            _ = @mulWithOverflow(u32, b, a, &b);
            b /= 0xffff;
            return Value{
                .r = r,
                .g = g,
                .b = b,
                .a = a,
            };
        }
    };

    pub const Alpha = struct {
        a: u8 = 0,

        fn toValue(c: Alpha) Value {
            var a: u32 = c.a;
            a |= a << 8;
            return Value{
                .r = a,
                .g = a,
                .b = a,
                .a = a,
            };
        }
    };

    pub const Alpha16 = struct {
        a: u16 = 0,

        fn toValue(c: Alpha16) Value {
            return Value{
                .r = c.a,
                .g = c.a,
                .b = c.a,
                .a = c.a,
            };
        }
    };

    pub const Gray = struct {
        y: u8 = 0,

        fn toValue(c: Gray) Value {
            var y: u32 = c.y;
            y |= y << 8;
            return Value{
                .r = y,
                .g = y,
                .b = y,
                .a = 0xffff,
            };
        }
    };

    pub const Gray16 = struct {
        y: u16 = 0,

        fn toValue(c: Gray16) Value {
            var y: u32 = c.y;
            return Value{
                .r = y,
                .g = y,
                .b = y,
                .a = 0xffff,
            };
        }
    };

    pub const RGBAModel = Model{ .convert = Model.rgbaModel };
    pub const RGBA64Model = Model{ .convert = Model.rgba64Model };
    pub const NRGBAModel = Model{ .convert = Model.nrgbaModel };
    pub const NRGBA64Model = Model{ .convert = Model.nrgba64Model };
    pub const AlphaModel = Model{ .convert = Model.alphaModel };
    pub const Alpha16Model = Model{ .convert = Model.alpha16Model };
    pub const GrayModel = Model{ .convert = Model.grayModel };
    pub const Gray16Model = Model{ .convert = Model.gray16Model };
    pub const YCbCrModel = Model{ .convert = Model.yCbCrModel };
    pub const NYCbCrAModel = Model{ .convert = Model.nYCbCrAModel };
    pub const CMYKModel = Model{ .convert = Model.cmykModel };

    pub const Black = Color{ .gray = Gray{ .y = 0 } };
    pub const White = Color{ .gray = Gray{ .y = 0xffff } };
    pub const Transparent = Color{ .alpha = Alpha{ .a = 0 } };
    pub const Opaque = Color{ .alpha16 = Alpha16{ .a = 0xffff } };

    fn sqDiff(x: u32, y: u32) u32 {
        var d: u32 = undefined;
        _ = @subWithOverflow(u32, y, x, &d);
        _ = @mulWithOverflow(u32, d, d, &d);
        return d >> 2;
    }

    fn short01(v: i32) i32 {
        if (@bitCast(u32, v) & 0xff000000 == 0) {
            return v >> 16;
        }
        return ~(v >> 31);
    }

    fn short02(v: i32) i32 {
        if (@bitCast(u32, v) & 0xff000000 == 0) {
            return v >> 16;
        }
        return ~(v >> 31) & 0xffff;
    }

    fn short8(v: i32) i32 {
        if (@bitCast(u32, v) & 0xff000000 == 0) {
            return v >> 8;
        }
        return ~(v >> 31) & 0xffff;
    }

    pub fn rgbToYCbCr(c: RGB) YCbCr {
        const r1 = @intCast(i32, c.r);
        const g1 = @intCast(i32, c.g);
        const b1 = @intCast(i32, c.b);
        const yy = (19595 * r1 + 38470 * g1 + 7471 * b1 + (1 << 15)) >> 16;
        const cb = short01(-11056 * r1 - 21712 * g1 + 32768 * b1 + (257 << 15));
        const cr = short01(32768 * r1 - 27440 * g1 - 5328 * b1 + (257 << 15));
        return YCbCr{
            .y = @truncate(u8, @bitCast(u32, yy)),
            .cr = @truncate(u8, @bitCast(u32, cr)),
            .cb = @truncate(u8, @bitCast(u32, cb)),
        };
    }

    pub const RGB = struct {
        r: u8,
        g: u8,
        b: u8,
    };

    pub fn yCbCrToRGB(c: YCbCr) RGB {
        const yy1 = @intCast(i32, c.y) * 0x10101;
        const cb1 = @intCast(i32, c.cb) - 128;
        const cr1 = @intCast(i32, c.cr) - 128;

        const r = short02(yy1 + 91881 * cr1);
        const g = short02(yy1 - 22554 * cb1 - 46802 * cr1);
        const b = short02(yy1 + 116130 * cb1);

        return RGB{
            .r = @truncate(u8, @bitCast(u32, r)),
            .g = @truncate(u8, @bitCast(u32, g)),
            .b = @truncate(u8, @bitCast(u32, b)),
        };
    }

    const YCbCr = struct {
        y: u8 = 0,
        cb: u8 = 0,
        cr: u8 = 0,

        pub fn toValue(self: YCbCr) Value {
            const yy1 = @intCast(i32, self.y) * 0x10101;
            const cb1 = @intCast(i32, self.cb) - 128;
            const cr1 = @intCast(i32, self.cr) - 128;

            const r = short8(yy1 + 91881 * cr1);
            const g = short8(yy1 - 22554 * cb1 - 46802 * cr1);
            const b = short8(yy1 + 116130 * cb1);
            return Value{
                .r = @intCast(u32, r),
                .g = @intCast(u32, g),
                .b = @intCast(u32, b),
                .a = 0xffff,
            };
        }
    };

    const NYCbCrA = struct {
        y: YCbCr,
        a: u8,

        pub fn toValue(self: NYCbCrA) Value {
            var yy1 = @intCast(i32, self.y.y) * 0x10101;
            var cb1 = @intCast(i32, self.y.cb) - 128;
            var cr1 = @intCast(i32, self.y.cr) - 128;

            const r = short8(yy1 + 91881 * cr1);
            const g = short8(yy1 - 22554 * cb1 - 46802 * cr1);
            const b = short8(yy1 + 116130 * cb1);
            const a = @intCast(u32, self.a) * 0x101;
            return Value{
                .r = @divTrunc(@bitCast(u32, r) * a, 0xffff),
                .g = @divTrunc(@bitCast(u32, g) * a, 0xffff),
                .b = @divTrunc(@bitCast(u32, b) * a, 0xffff),
                .a = a,
            };
        }
    };

    const Palette = struct {
        colors: []Color,

        const WebSafe: Palette = comptime {
            var colors: [6 * 6 * 6]Color = undefined;
            var r: usize = 0;
            while (r < 6) : (r += 1) {
                var g: usize = 0;
                while (g < 6) : (g += 1) {
                    var b: usize = 0;
                    while (b < 6) : (b += 1) {
                        colors[36 * r + 6 * g + b] = Color{
                            .rgba = RGBA{
                                .r = @truncate(u8, 0x33 * r),
                                .g = @truncate(u8, 0x33 * g),
                                .b = @truncate(u8, 0x33 * b),
                                .a = 0xff,
                            },
                        };
                    }
                }
            }
            const p = Palette{ .colors = colors[0..] };
            return p;
        };

        const Plan9: Palette = comptime {
            var colors: [256]Color = undefined;
            var r: usize = 0;
            var i: usize = 0;
            while (r != 4) : (r += 1) {
                var v: usize = 0;
                while (v != 4) : ({
                    v += 1;
                    i += 16;
                }) {
                    var g: usize = 0;
                    var j: usize = v - r;
                    while (g != 4) : (g += 1) {
                        var b: usize = 0;
                        while (b != 4) : ({
                            b += 1;
                            j += 1;
                        }) {
                            var den = r;
                            if (g > den) {
                                den = g;
                            }
                            if (b > den) {
                                den = b;
                            }
                            if (den == 0) {
                                colors[i + (j & 0x0f)] = Color{
                                    .rgba = RGBA{
                                        .r = 0x11 * v,
                                        .g = 0x11 * v,
                                        .b = 0x11 * v,
                                        .a = 0xff,
                                    },
                                };
                            } else {
                                colors[i + (j & 0x0f)] = Color{
                                    .rgba = RGBA{
                                        .r = (r * num) / den,
                                        .g = (g * num) / den,
                                        .b = (b * num) / den,
                                        .a = 0xff,
                                    },
                                };
                            }
                        }
                    }
                }
            }
            const p = Palette{ .colors = colors[0..] };
            return p;
        };

        pub fn convert(self: Palette, c: Color) ?Color {
            if (self.colors.len == 0) {
                return null;
            }
            return self.colors[self.index(c)];
        }

        pub fn index(self: Palette, c: Color) usize {
            const value = c.toValue();
            var ret: usize = 0;
            var best_sum: u32 = (1 << 32) - 1;
            for (self.colors) |v, i| {
                const value2 = v.toValue();
                const sum = sqDiff(value.r, value2.r) +
                    sqDiff(value.g, value2.g) +
                    sqDiff(value.b, value2.b) +
                    sqDiff(value.a, value2.a);
                if (sum < best_sum) {
                    if (sum == 0) {
                        return i;
                    }
                    ret = i;
                    best_sum = sum;
                }
            }
            return ret;
        }
    };

    pub fn rgbToCMYK(a: RGB) CMYK {
        const rr = @intCast(u32, a.r);
        const gg = @intCast(u32, a.g);
        const bb = @intCast(u32, a.b);
        var w = rr;
        if (w < gg) {
            w = gg;
        }
        if (w < bb) {
            w = bb;
        }
        if (w == 0) {
            return CMYK{
                .c = 0,
                .m = 0,
                .y = 0,
                .k = 0xff,
            };
        }
        const c = ((w - rr) * 0xff) / w;
        const m = ((w - gg) * 0xff) / w;
        const y = ((w - bb) * 0xff) / w;
        return CMYK{
            .c = @truncate(u8, c),
            .m = @truncate(u8, m),
            .y = @truncate(u8, y),
            .k = @truncate(u8, 0xff - w),
        };
    }

    pub fn cmykToRGB(a: CMYK) RGB {
        const w = 0xffff - @intCast(u32, a.k) * 0x101;
        const r = ((0xffff - @intCast(u32, a.c) * 0x101) * w) / 0xffff;
        const g = ((0xffff - @intCast(u32, a.m) * 0x101) * w) / 0xffff;
        const b = ((0xffff - @intCast(u32, a.y) * 0x101) * w) / 0xffff;
        return RGB{
            .r = @truncate(u8, r >> 8),
            .g = @truncate(u8, g >> 8),
            .b = @truncate(u8, b >> 8),
        };
    }

    pub const CMYK = struct {
        c: u8 = 0,
        m: u8 = 0,
        y: u8 = 0,
        k: u8 = 0,

        pub fn toValue(self: CMYK) Value {
            const w = 0xffff - @intCast(u32, self.k) * 0x101;
            const r = ((0xffff - @intCast(u32, self.c) * 0x101) * w) / 0xffff;
            const g = ((0xffff - @intCast(u32, self.m) * 0x101) * w) / 0xffff;
            const b = ((0xffff - @intCast(u32, self.y) * 0x101) * w) / 0xffff;
            return Value{
                .r = r,
                .g = g,
                .b = b,
                .a = 0xffff,
            };
        }
    };
};

// ======== Color TESTS

test "sqDiff" {
    const ts = struct {
        fn orig(x: u32, y: u32) u32 {
            var d: u32 = 0;
            if (x > y) {
                d = x - y;
            } else {
                d = y - x;
            }
            _ = @mulWithOverflow(u32, d, d, &d);
            return d >> 2;
        }
    };
    const kases = [_]u32{
        0,
        1,
        2,
        0x0fffd,
        0x0fffe,
        0x0ffff,
        0x10000,
        0x10001,
        0x10002,
        0xfffffffd,
        0xfffffffe,
        0xffffffff,
    };
    for (kases) |x| {
        for (kases) |y| {
            const got = Color.sqDiff(x, y);
            const want = ts.orig(x, y);
            testing.expectEqual(want, got);
        }
    }
}
test "TestYCbCrRoundtrip" {
    var r: usize = 0;
    while (r < 256) : (r += 7) {
        var g: usize = 0;
        while (g < 256) : (g += 5) {
            var b: usize = 0;
            while (b < 256) : (b += 3) {
                const o = Color.RGB{
                    .r = @truncate(u8, r),
                    .g = @truncate(u8, g),
                    .b = @truncate(u8, b),
                };
                const v0 = Color.rgbToYCbCr(o);
                const v1 = Color.yCbCrToRGB(v0);
                if (ytest.delta(o.r, v1.r) > 2 or
                    ytest.delta(o.g, v1.g) > 2 or
                    ytest.delta(o.b, v1.b) > 2)
                {
                    print("{any} {any} {any}", .{ v0, o, v1 });
                    testing.expectEqual(o, v1);
                }
            }
        }
    }
}

test "TestYCbCrToRGBConsistency" {
    // TestYCbCrToRGBConsistency tests that calling the RGBA method (16 bit color)
    // then truncating to 8 bits is equivalent to calling the YCbCrToRGB function (8
    // bit color).

    var y: usize = 0;
    while (y < 256) : (y += 7) {
        var cb: usize = 0;
        while (cb < 256) : (cb += 5) {
            var cr: usize = 0;
            while (cr < 256) : (cr += 3) {
                const o = Color.YCbCr{
                    .y = @truncate(u8, y),
                    .cb = @truncate(u8, cb),
                    .cr = @truncate(u8, cr),
                };
                const v0 = o.toValue();
                const v1 = Color.RGB{
                    .r = @truncate(u8, v0.r >> 8),
                    .g = @truncate(u8, v0.g >> 8),
                    .b = @truncate(u8, v0.b >> 8),
                };
                const v2 = Color.yCbCrToRGB(o);
                // print("{any} {any} {any}", .{ v0, v1, v2 });
                testing.expectEqual(v1, v2);
            }
        }
    }
}

test "TestYCbCrGray" {
    // TestYCbCrGray tests that YCbCr colors are a superset of Gray colors.
    var i: usize = 0;
    while (i < 256) : (i += 1) {
        const c0 = Color{
            .yCbCr = Color.YCbCr{
                .y = @intCast(u8, i),
                .cb = 0x80,
                .cr = 0x80,
            },
        };
        const c1 = Color{
            .gray = .{
                .y = @intCast(u8, i),
            },
        };
        ytest.eq(c0, c1);
    }
}

test "TestNYCbCrAAlpha" {
    // TestNYCbCrAAlpha tests that NYCbCrA colors are a superset of Alpha colors.
    var i: usize = 0;
    while (i < 256) : (i += 1) {
        const c0 = Color{
            .nYCbCrA = Color.NYCbCrA{
                .y = .{
                    .y = 0xff,
                    .cb = 0x80,
                    .cr = 0x80,
                },
                .a = @intCast(u8, i),
            },
        };
        const c1 = Color{
            .alpha = .{
                .a = @intCast(u8, i),
            },
        };
        ytest.eq(c0, c1);
    }
}

test "TestNYCbCrAYCbCr" {
    // TestNYCbCrAYCbCr tests that NYCbCrA colors are a superset of YCbCr colors.
    var i: usize = 0;
    while (i < 256) : (i += 1) {
        const c0 = Color{
            .nYCbCrA = .{
                .y = .{
                    .y = @intCast(u8, i),
                    .cb = 0x40,
                    .cr = 0xc0,
                },
                .a = 0xff,
            },
        };
        const c1 = Color{
            .yCbCr = .{
                .y = @intCast(u8, i),
                .cb = 0x40,
                .cr = 0xc0,
            },
        };
        ytest.eq(c0, c1);
    }
}
const ytest = struct {
    fn delta(x: u8, y: u8) u8 {
        if (x >= y) {
            return x - y;
        }
        return y - x;
    }

    fn eq(c0: Color, c1: Color) void {
        testing.expectEqual(c0.toValue(), c1.toValue());
    }
};
test "TestCMYKRoundtrip" {
    // TestCMYKRoundtrip tests that a subset of RGB space can be converted to CMYK
    // and back to within 1/256 tolerance.
    var r: usize = 0;
    while (r < 256) : (r += 7) {
        var g: usize = 0;
        while (g < 256) : (g += 5) {
            var b: usize = 0;
            while (b < 256) : (b += 3) {
                const v0 = Color.RGB{
                    .r = @intCast(u8, r),
                    .g = @intCast(u8, g),
                    .b = @intCast(u8, b),
                };
                const v1 = Color.rgbToCMYK(v0);
                const v2 = Color.cmykToRGB(v1);
                if (ytest.delta(v0.r, v2.r) > 1 or
                    ytest.delta(v0.g, v2.g) > 1 or
                    ytest.delta(v0.g, v2.g) > 1)
                {
                    testing.expectEqual(v0, v2);
                }
            }
        }
    }
}

test "TestCMYKToRGBConsistency" {
    // TestCMYKToRGBConsistency tests that calling the RGBA method (16 bit color)
    // then truncating to 8 bits is equivalent to calling the CMYKToRGB function (8
    // bit color).
    var c: usize = 0;
    while (c < 256) : (c += 7) {
        var m: usize = 0;
        while (m < 256) : (m += 5) {
            var y: usize = 0;
            while (y < 256) : (y += 3) {
                var k: usize = 0;
                while (k < 256) : (k += 11) {
                    const v0 = Color.CMYK{
                        .c = @intCast(u8, c),
                        .m = @intCast(u8, m),
                        .y = @intCast(u8, y),
                        .k = @intCast(u8, k),
                    };
                    const v1 = v0.toValue();
                    const v2 = Color.RGB{
                        .r = @truncate(u8, v1.r >> 8),
                        .g = @truncate(u8, v1.g >> 8),
                        .b = @truncate(u8, v1.b >> 8),
                    };
                    const v3 = Color.cmykToRGB(v0);
                    testing.expectEqual(v2, v3);
                }
            }
        }
    }
}

test "TestCMYKGray" {
    // TestCMYKGray tests that CMYK colors are a superset of Gray colors.
    var i: usize = 0;
    while (i < 256) : (i += 1) {
        const v0 = Color{
            .cMYK = Color.CMYK{
                .c = 0x00,
                .m = 0x00,
                .y = 0x00,
                .k = @intCast(u8, 255 - i),
            },
        };
        const v1 = Color{
            .gray = .{
                .y = @intCast(u8, i),
            },
        };
        ytest.eq(v0, v1);
    }
}

test "TestPalette" {
    var colors = [_]Color{
        .{
            .rgba = Color.RGBA{
                .r = 0xff,
                .g = 0xff,
                .b = 0xff,
                .a = 0xff,
            },
        },
        .{
            .rgba = .{
                .r = 0x80,
                .g = 0x00,
                .b = 0x00,
                .a = 0xff,
            },
        },
        .{
            .rgba = .{
                .r = 0x7f,
                .g = 0x00,
                .b = 0x00,
                .a = 0x7f,
            },
        },
        .{
            .rgba = .{
                .r = 0x00,
                .g = 0x00,
                .b = 0x00,
                .a = 0x7f,
            },
        },
        .{
            .rgba = .{
                .r = 0x00,
                .g = 0x00,
                .b = 0x00,
                .a = 0x00,
            },
        },
        .{
            .rgba = .{
                .r = 0x40,
                .g = 0x40,
                .b = 0x40,
                .a = 0x40,
            },
        },
    };
    const p = Color.Palette{
        .colors = colors[0..],
    };
    for (p.colors) |c, i| {
        const j = p.index(c);
        testing.expectEqual(i, j);
    }
    const got = p.convert(Color{
        .rgba = .{
            .r = 0x80,
            .g = 0x00,
            .b = 0x00,
            .a = 0x80,
        },
    });
    const want = Color{
        .rgba = .{
            .r = 0x7f,
            .g = 0x00,
            .b = 0x00,
            .a = 0x7f,
        },
    };
    ytest.eq(want, got.?);
}

pub const Config = struct {
    model: color.Model,
    width: isize,
    height: isize,
};

pub const Image = union(enum) {
    rgba: RGBA,
    rgba64: RGBA64,
    nrgba: NRGBA,
    nrgba64: NRGBA64,
    alpha: Alpha,
    alpha16: Alpha16,
    gray: Gray,
    gray16: Gray16,
    cmyk: CMYK,
    yCbCr: YCbCr,

    pub fn colorModel(self: Image) Color.Model {
        return switch (self) {
            .rgba => Color.RGBAModel,
            .rgba64 => Color.RGBA64Model,
            .nrgba => Color.RGBA64Model,
            .nrgba64 => Color.NRGBA64Model,
            .alpha => Color.AlphaModel,
            .alpha16 => Color.Alpha16Model,
            .gray => Color.GrayModel,
            .gray16 => Color.Gray16Model,
            .cmyk => Color.CMYKModel,
            .yCbCr => Color.YCbCrModel,
        };
    }

    pub fn bounds(self: Image) Rectangle {
        return switch (self) {
            .rgba => |i| i.rect,
            .rgba64 => |i| i.rect,
            .nrgba => |i| i.rect,
            .nrgba64 => |i| i.rect,
            .alpha => |i| i.rect,
            .alpha16 => |i| i.rect,
            .gray => |i| i.rect,
            .gray16 => |i| i.rect,
            .cmyk => |i| i.rect,
            .yCbCr => |i| i.rect,
        };
    }

    // used for testing. This returns underlying pix slice for easily freeing up
    // test images
    fn get_pix(self: Image) []u8 {
        return switch (self) {
            .rgba => |i| i.pix,
            .rgba64 => |i| i.pix,
            .nrgba => |i| i.pix,
            .nrgba64 => |i| i.pix,
            .alpha => |i| i.pix,
            .alpha16 => |i| i.pix,
            .gray => |i| i.pix,
            .gray16 => |i| i.pix,
            .cmyk => |i| i.pix,
            .yCbCr => unreachable,
        };
    }

    pub fn at(self: Image, x: isize, y: isize) Color {
        return switch (self) {
            .rgba => |i| i.at(x, y),
            .rgba64 => |i| i.at(x, y),
            .nrgba => |i| i.at(x, y),
            .nrgba64 => |i| i.at(x, y),
            .alpha => |i| i.at(x, y),
            .alpha16 => |i| i.at(x, y),
            .gray => |i| i.at(x, y),
            .gray16 => |i| i.at(x, y),
            .cmyk => |i| i.at(x, y),
            .yCbCr => |i| i.at(x, y),
        };
    }

    pub fn set(self: Image, x: isize, y: isize, c: Color) void {
        switch (self) {
            .rgba => |i| i.set(x, y, c),
            .rgba64 => |i| i.set(x, y, c),
            .nrgba => |i| i.set(x, y, c),
            .nrgba64 => |i| i.set(x, y, c),
            .alpha => |i| i.set(x, y, c),
            .alpha16 => |i| i.set(x, y, c),
            .gray => |i| i.set(x, y, c),
            .gray16 => |i| i.set(x, y, c),
            .cmyk => |i| i.set(x, y, c),
            .yCbCr => unreachable,
        }
    }

    pub fn subImage(self: Image, r: Rectangle) ?Image {
        return switch (self) {
            .rgba => |i| i.subImage(r),
            .rgba64 => |i| i.subImage(r),
            .nrgba => |i| i.subImage(r),
            .nrgba64 => |i| i.subImage(r),
            .alpha => |i| i.subImage(r),
            .alpha16 => |i| i.subImage(r),
            .gray => |i| i.subImage(r),
            .gray16 => |i| i.subImage(r),
            .cmyk => |i| i.subImage(r),
            .yCbCr => |i| i.subImage(r),
        };
    }

    pub fn @"opaque"(self: Image) bool {
        return switch (self) {
            .rgba => |i| i.@"opaque"(),
            .rgba64 => |i| i.@"opaque"(),
            .nrgba => |i| i.@"opaque"(),
            .nrgba64 => |i| i.@"opaque"(),
            .alpha => |i| i.@"opaque"(),
            .alpha16 => |i| i.@"opaque"(),
            .gray => |i| i.@"opaque"(),
            .gray16 => |i| i.@"opaque"(),
            .cmyk => |i| i.@"opaque"(),
            .yCbCr => unreachable,
        };
    }

    pub fn luminance(self: Image, a: *std.mem.Allocator) !Luminance {
        const b = self.bounds();
        const height = b.dx();
        const width = b.dy();
        var lu = try a.alloc(u8, height * width);
        var index: isize = 0;
        var y: isize = b.min.Y;
        while (y < b.max.y) : (y += 1) {
            var x = b.min.x;
            while (x < b.max.x) : (x += 1) {
                const c = self.at(x, y).toValue();
                const lum = (c.r + 2 * c.g + c.b) * 255 / (4 * 0xffff);
                lu[index] = @intCast(u8, (lum * c.a + (0xffff - c.a) * 255) / 0xffff);
                index += 1;
            }
        }
        return Luminance{
            .pix = lu,
            .dimensions = .{
                .height = height,
                .width = width,
            },
        };
    }

    pub const RGBA = struct {
        // pix holds the image's pixels, in R, G, B, A order. The pixel at
        // (x, y) starts at pix[(y-Rect.Min.Y)*Stride + (x-Rect.Min.X)*4].
        pix: []u8 = undefined,
        // stride is the Pix stride (in bytes) between vertically adjacent pixels.
        stride: isize = 0,
        // rect is the image's bounds.
        rect: Rectangle = Rectangle{},

        pub fn init(a: *std.mem.Allocator, r: Rectangle) !RGBA {
            return RGBA{
                .pix = try createPix(a, 4, r, "RGBA"),
                .stride = 4 * r.dx(),
                .rect = r,
            };
        }

        pub fn at(self: RGBA, x: isize, y: isize) Color {
            const point = Point{ .x = x, .y = y };
            if (!point.in(self.rect)) return .{ .rgba = .{} };
            const i = self.pixOffset(x, y);
            const s = self.pix[i .. i + 4];
            return Color{
                .rgba = .{
                    .r = s[0],
                    .g = s[1],
                    .b = s[2],
                    .a = s[3],
                },
            };
        }

        pub fn pixOffset(self: RGBA, x: isize, y: isize) usize {
            const v = (y - self.rect.min.y) * self.stride + (x - self.rect.min.x) * 4;
            return @intCast(usize, v);
        }

        pub fn set(self: RGBA, x: isize, y: isize, c: Color) void {
            const point = Point{ .x = x, .y = y };
            if (point.in(self.rect)) {
                const i = self.pixOffset(x, y);
                const c1 = Color.RGBAModel.convert(c).toValue();
                const s = self.pix[i .. i + 4];
                s[0] = @truncate(u8, c1.r);
                s[1] = @truncate(u8, c1.g);
                s[2] = @truncate(u8, c1.b);
                s[3] = @truncate(u8, c1.a);
            }
        }

        pub fn subImage(self: RGBA, r: Rectangle) ?Image {
            const n = r.intersect(self.rect);
            if (r.empty()) return null;
            const i = self.pixOffset(n.min.x, n.min.y);
            return Image{
                .rgba = RGBA{
                    .pix = self.pix[i..],
                    .stride = self.stride,
                    .rect = n,
                },
            };
        }

        pub fn @"opaque"(self: RGBA) bool {
            if (self.rect.empty()) {
                return true;
            }
            var i_0: isize = 3;
            var i_1: isize = self.rect.dx() * 4;
            var y: isize = self.rect.min.y;
            while (y < self.rect.max.y) : (y += 1) {
                var i: isize = i_0;
                while (i < i_1) : (i += 4) {
                    if (self.pix[@intCast(usize, i)] != 0xff) {
                        return false;
                    }
                }
                i_0 += self.stride;
                i_1 += self.stride;
            }
            return true;
        }
    };

    const Luminance = struct {
        pix: []const u8,
        dimension: Dimension = Dimension{},
        data: Dimension = Dimension{},
        left: isize,
        top: isize,
        pub const Dimension = struct {
            height: isize = 0,
            width: isize = 0,
        };

        pub fn crop(self: Luminance, left: isize, top: isize, width: isize, height: isize) Luminance {
            if ((left + width > self.data.width) or (top + height > self.data.height)) {
                std.debug.panic("IllegalArgumentException: Crop rectangle does not fit within image data");
            }
            return Luminance{
                .pix = self.pix,
                .dimension = .{
                    .height = height,
                    .widht = width,
                },
                .data = .{
                    .height = self.height,
                    .width = self.width,
                },
                .left = self.left + left,
                .top = self.top + top,
            };
        }
    };

    fn pixelBufferLength(bytesPerPixel: isize, r: Rectangle, imageTypeName: []const u8) usize {
        const totalLength = geom.mul3NonNeg(bytesPerPixel, r.dx(), r.dy());
        if (totalLength < 0) std.debug.panic("init: {any} Rectangle has huge or negative dimensions", .{imageTypeName});
        return @intCast(usize, totalLength);
    }

    fn createPix(a: *std.mem.Allocator, size: isize, r: Rectangle, name: []const u8) ![]u8 {
        var pix = try a.alloc(u8, pixelBufferLength(size, r, "RGBA"));
        var i: usize = 0;
        while (i < pix.len) : (i += 1) {
            pix[i] = 0;
        }
        return pix;
    }

    pub const RGBA64 = struct {
        pix: []u8 = undefined,
        stride: isize = 0,
        rect: Rectangle = Rectangle{},

        pub fn init(a: *std.mem.Allocator, r: Rectangle) !RGBA64 {
            return RGBA64{
                .pix = try createPix(a, 8, r, "RGBA64"),
                .stride = 8 * r.dx(),
                .rect = r,
            };
        }

        pub fn at(self: RGBA64, x: isize, y: isize) Color {
            const point = Point{ .x = x, .y = y };
            if (!point.in(self.rect)) return .{ .rgba64 = .{} };
            const i = self.pixOffset(x, y);
            const s = self.pix[i .. i + 8];
            return Color{
                .rgba64 = .{
                    .r = (@intCast(u16, s[0]) << 8) | @intCast(u16, s[1]),
                    .g = @intCast(u16, s[2]) << 8 | @intCast(u16, s[3]),
                    .b = @intCast(u16, s[4]) << 8 | @intCast(u16, s[5]),
                    .a = @intCast(u16, s[6]) << 8 | @intCast(u16, s[7]),
                },
            };
        }
        pub fn pixOffset(self: RGBA64, x: isize, y: isize) usize {
            const v = (y - self.rect.min.y) * self.stride + (x - self.rect.min.x) * 8;
            return @intCast(usize, v);
        }

        pub fn set(self: RGBA64, x: isize, y: isize, c: Color) void {
            const point = Point{ .x = x, .y = y };
            if (point.in(self.rect)) {
                const i = self.pixOffset(x, y);
                const c1 = Color.RGBA64Model.convert(c).toValue();
                var s = self.pix[i .. i + 8];
                s[0] = @truncate(u8, c1.r >> 8);
                s[1] = @truncate(u8, c1.r);
                s[2] = @truncate(u8, c1.g >> 8);
                s[3] = @truncate(u8, c1.g);
                s[4] = @truncate(u8, c1.b >> 8);
                s[5] = @truncate(u8, c1.b);
                s[6] = @truncate(u8, c1.a >> 8);
                s[7] = @truncate(u8, c1.a);
            }
        }

        pub fn subImage(self: RGBA64, n: Rectangle) ?Image {
            const r = n.intersect(self.rect);
            if (r.empty()) return null;
            const i = self.pixOffset(r.min.x, r.min.y);
            return Image{
                .rgba64 = RGBA64{
                    .pix = self.pix[i..],
                    .stride = self.stride,
                    .rect = r,
                },
            };
        }

        pub fn @"opaque"(self: RGBA64) bool {
            if (self.rect.empty()) return true;
            var i_0: isize = 6;
            var i_1: isize = self.rect.dx() * 8;
            var y = self.rect.min.y;
            while (y < self.rect.max.y) : (y += 1) {
                var i = i_0;
                while (i < i_1) : (i += 8) {
                    if (self.pix[@intCast(usize, i) + 0] != 0xff or self.pix[@intCast(usize, i) + 1] != 0xff) {
                        return false;
                    }
                }
                i_0 += self.stride;
                i_1 += self.stride;
            }
            return true;
        }
    };

    pub const NRGBA = struct {
        pix: []u8,
        stride: isize,
        rect: Rectangle,

        pub fn init(a: *std.mem.Allocator, r: Rectangle) !NRGBA {
            return NRGBA{
                .pix = try createPix(a, 4, r, "NRGBA"),
                .stride = 4 * r.dx(),
                .rect = r,
            };
        }

        pub fn at(self: NRGBA, x: isize, y: isize) Color {
            const point = Point{ .x = x, .y = y };
            if (!point.in(self.rect)) return .{ .nrgba = .{} };
            const i = self.pixOffset(x, y);
            const s = self.pix[i .. i + 4];
            return Color{
                .nrgba = .{
                    .r = s[0],
                    .g = s[1],
                    .b = s[2],
                    .a = s[3],
                },
            };
        }

        pub fn set(self: NRGBA, x: isize, y: isize, c: Color) void {
            const point = Point{ .x = x, .y = y };
            if (point.in(self.rect)) {
                const i = self.pixOffset(x, y);
                const c1 = Color.NRGBAModel.convert(c).toValue();
                var s = self.pix[i .. i + 4];
                s[0] = @truncate(u8, c1.r);
                s[1] = @truncate(u8, c1.g);
                s[2] = @truncate(u8, c1.b);
                s[3] = @truncate(u8, c1.a);
            }
        }

        pub fn subImage(self: NRGBA, n: Rectangle) ?Image {
            const r = n.intersect(self.rect);
            if (r.empty()) return null;
            const i = self.pixOffset(r.min.x, r.min.y);
            return Image{
                .nrgba = NRGBA{
                    .pix = self.pix[i..],
                    .stride = self.stride,
                    .rect = r,
                },
            };
        }

        pub fn @"opaque"(self: NRGBA) bool {
            if (self.rect.empty()) return true;
            var i_0: isize = 3;
            var i_1: isize = self.rect.dx() * 4;
            var y = self.rect.min.y;
            while (y < self.rect.max.y) : (y += 1) {
                var i = i_0;
                while (i < i_1) : (i += 4) {
                    if (self.pix[@intCast(usize, i)] != 0xff) {
                        return false;
                    }
                }
                i_0 += self.stride;
                i_1 += self.stride;
            }
            return true;
        }

        pub fn pixOffset(self: NRGBA, x: isize, y: isize) usize {
            const v = (y - self.rect.min.y) * self.stride + (x - self.rect.min.x) * 4;
            return @intCast(usize, v);
        }
    };
    pub const NRGBA64 = struct {
        pix: []u8,
        stride: isize,
        rect: Rectangle,

        pub fn init(a: *std.mem.Allocator, r: Rectangle) !NRGBA64 {
            return NRGBA64{
                .pix = try createPix(a, 8, r, "NRGBA64"),
                .stride = 8 * r.dx(),
                .rect = r,
            };
        }

        pub fn at(self: NRGBA64, x: isize, y: isize) Color {
            const point = Point{ .x = x, .y = y };
            if (!point.in(self.rect)) return .{ .nrgba64 = .{} };
            const i = self.pixOffset(x, y);
            const s = self.pix[i .. i + 8];
            return Color{
                .nrgba64 = .{
                    .r = (@intCast(u16, s[0]) << 8) | @intCast(u16, s[1]),
                    .g = @intCast(u16, s[2]) << 8 | @intCast(u16, s[3]),
                    .b = @intCast(u16, s[4]) << 8 | @intCast(u16, s[5]),
                    .a = @intCast(u16, s[6]) << 8 | @intCast(u16, s[7]),
                },
            };
        }

        pub fn pixOffset(self: NRGBA64, x: isize, y: isize) usize {
            const v = (y - self.rect.min.y) * self.stride + (x - self.rect.min.x) * 8;
            return @intCast(usize, v);
        }

        pub fn set(self: NRGBA64, x: isize, y: isize, c: Color) void {
            const point = Point{ .x = x, .y = y };
            if (point.in(self.rect)) {
                const i = self.pixOffset(x, y);
                const c1 = Color.NRGBA64Model.convert(c).toValue();
                var s = self.pix[i .. i + 8];
                s[0] = @truncate(u8, c1.r >> 8);
                s[1] = @truncate(u8, c1.r);
                s[2] = @truncate(u8, c1.g >> 8);
                s[3] = @truncate(u8, c1.g);
                s[4] = @truncate(u8, c1.b >> 8);
                s[5] = @truncate(u8, c1.b);
                s[6] = @truncate(u8, c1.a >> 8);
                s[7] = @truncate(u8, c1.a);
            }
        }

        pub fn subImage(self: NRGBA64, n: Rectangle) ?Image {
            const r = n.intersect(self.rect);
            if (r.empty()) return null;
            const i = self.pixOffset(r.min.x, r.min.y);
            return Image{
                .nrgba64 = NRGBA64{
                    .pix = self.pix[i..],
                    .stride = self.stride,
                    .rect = r,
                },
            };
        }

        pub fn @"opaque"(self: NRGBA64) bool {
            if (self.rect.empty()) return true;
            var i_0: isize = 6;
            var i_1: isize = self.rect.dx() * 8;
            var y = self.rect.min.y;
            while (y < self.rect.max.y) : (y += 1) {
                var i = i_0;
                while (i < i_1) : (i += 8) {
                    if (self.pix[@intCast(usize, i) + 0] != 0xff or self.pix[@intCast(usize, i) + 1] != 0xff) {
                        return false;
                    }
                }
                i_0 += self.stride;
                i_1 += self.stride;
            }
            return true;
        }
    };

    pub const Alpha = struct {
        pix: []u8,
        stride: isize,
        rect: Rectangle,

        pub fn init(a: *std.mem.Allocator, r: Rectangle) !Alpha {
            return Alpha{
                .pix = try createPix(a, 1, r, "Alpha"),
                .stride = 1 * r.dx(),
                .rect = r,
            };
        }

        pub fn at(self: Alpha, x: isize, y: isize) Color {
            const point = Point{ .x = x, .y = y };
            if (!point.in(self.rect)) return .{ .alpha = .{} };
            const i = self.pixOffset(x, y);
            return Color{
                .alpha = .{
                    .a = self.pix[i],
                },
            };
        }

        pub fn pixOffset(self: Alpha, x: isize, y: isize) usize {
            const v = (y - self.rect.min.y) * self.stride + (x - self.rect.min.x) * 1;
            return @intCast(usize, v);
        }

        pub fn set(self: Alpha, x: isize, y: isize, c: Color) void {
            const point = Point{ .x = x, .y = y };
            if (point.in(self.rect)) {
                const i = self.pixOffset(x, y);
                self.pix[i] = Color.AlphaModel.convert(c).alpha.a;
            }
        }

        pub fn subImage(self: Alpha, n: Rectangle) ?Image {
            const r = n.intersect(self.rect);
            if (r.empty()) return null;
            const i = self.pixOffset(r.min.x, r.min.y);
            return Image{
                .alpha = Alpha{
                    .pix = self.pix[i..],
                    .stride = self.stride,
                    .rect = r,
                },
            };
        }

        pub fn @"opaque"(self: Alpha) bool {
            if (self.rect.empty()) return true;
            var i_0: isize = 0;
            var i_1: isize = self.rect.dx() * 1;
            var y = self.rect.min.y;
            while (y < self.rect.max.y) : (y += 1) {
                var i = i_0;
                while (i < i_1) : (i += 8) {
                    if (self.pix[@intCast(usize, i)] != 0xff) {
                        return false;
                    }
                }
                i_0 += self.stride;
                i_1 += self.stride;
            }
            return true;
        }
    };

    pub const Alpha16 = struct {
        pix: []u8,
        stride: isize,
        rect: Rectangle,

        pub fn init(a: *std.mem.Allocator, r: Rectangle) !Alpha16 {
            return Alpha16{
                .pix = try createPix(a, 2, r, "Alpha16"),
                .stride = 2 * r.dx(),
                .rect = r,
            };
        }

        pub fn at(self: Alpha16, x: isize, y: isize) Color {
            const point = Point{ .x = x, .y = y };
            if (!point.in(self.rect)) return .{ .alpha16 = .{} };
            const i = self.pixOffset(x, y);
            return Color{
                .alpha16 = .{
                    .a = @intCast(u16, self.pix[i]) << 8 | @intCast(u16, self.pix[i + 1]),
                },
            };
        }

        pub fn pixOffset(self: Alpha16, x: isize, y: isize) usize {
            const v = (y - self.rect.min.y) * self.stride + (x - self.rect.min.x) * 2;
            return @intCast(usize, v);
        }

        pub fn set(self: Alpha16, x: isize, y: isize, c: Color) void {
            const point = Point{ .x = x, .y = y };
            if (point.in(self.rect)) {
                const i = self.pixOffset(x, y);
                const c1 = Color.Alpha16Model.convert(c).alpha16;
                self.pix[i + 0] = @truncate(u8, c1.a >> 8);
                self.pix[i + 1] = @truncate(u8, c1.a);
            }
        }

        pub fn subImage(self: Alpha16, n: Rectangle) ?Image {
            const r = n.intersect(self.rect);
            if (r.empty()) return null;
            const i = self.pixOffset(r.min.x, r.min.y);
            return Image{
                .alpha16 = Alpha16{
                    .pix = self.pix[i..],
                    .stride = self.stride,
                    .rect = r,
                },
            };
        }

        pub fn @"opaque"(self: Alpha16) bool {
            if (self.rect.empty()) return true;
            var i_0: isize = 0;
            var i_1: isize = self.rect.dx() * 2;
            var y = self.rect.min.y;
            while (y < self.rect.max.y) : (y += 1) {
                var i = i_0;
                while (i < i_1) : (i += 8) {
                    if (self.pix[@intCast(usize, i) + 0] != 0xff or self.pix[@intCast(usize, i) + 1] != 0xff) {
                        return false;
                    }
                }
                i_0 += self.stride;
                i_1 += self.stride;
            }
            return true;
        }
    };

    pub const Gray = struct {
        pix: []u8,
        stride: isize,
        rect: Rectangle,

        pub fn init(a: *std.mem.Allocator, r: Rectangle) !Gray {
            return Gray{
                .pix = try createPix(a, 1, r, "Gray"),
                .stride = 1 * r.dx(),
                .rect = r,
            };
        }

        pub fn at(self: Gray, x: isize, y: isize) Color {
            const point = Point{ .x = x, .y = y };
            if (!point.in(self.rect)) return .{ .gray = .{} };
            const i = self.pixOffset(x, y);
            return Color{
                .gray = .{
                    .y = self.pix[i],
                },
            };
        }

        pub fn pixOffset(self: Gray, x: isize, y: isize) usize {
            const v = (y - self.rect.min.y) * self.stride + (x - self.rect.min.x) * 1;
            return @intCast(usize, v);
        }

        pub fn set(self: Gray, x: isize, y: isize, c: Color) void {
            const point = Point{ .x = x, .y = y };
            if (point.in(self.rect)) {
                const i = self.pixOffset(x, y);
                self.pix[i] = Color.GrayModel.convert(c).gray.y;
            }
        }

        pub fn subImage(self: Gray, n: Rectangle) ?Image {
            const r = n.intersect(self.rect);
            if (r.empty()) return null;
            const i = self.pixOffset(r.min.x, r.min.y);
            return Image{
                .gray = Gray{
                    .pix = self.pix[i..],
                    .stride = self.stride,
                    .rect = r,
                },
            };
        }
        pub fn @"opaque"(self: Gray) bool {
            return true;
        }
    };

    pub const Gray16 = struct {
        pix: []u8,
        stride: isize,
        rect: Rectangle,

        pub fn init(a: *std.mem.Allocator, r: Rectangle) !Gray16 {
            return Gray16{
                .pix = try createPix(a, 2, r, "Gray16"),
                .stride = 2 * r.dx(),
                .rect = r,
            };
        }
        pub fn at(self: Gray16, x: isize, y: isize) Color {
            const point = Point{ .x = x, .y = y };
            if (!point.in(self.rect)) return .{ .gray16 = .{} };
            const i = self.pixOffset(x, y);
            return Color{
                .gray16 = .{
                    .y = @intCast(u16, self.pix[i]) << 8 | @intCast(u16, self.pix[i + 1]),
                },
            };
        }

        pub fn pixOffset(self: Gray16, x: isize, y: isize) usize {
            const v = (y - self.rect.min.y) * self.stride + (x - self.rect.min.x) * 2;
            return @intCast(usize, v);
        }
        pub fn set(self: Gray16, x: isize, y: isize, c: Color) void {
            const point = Point{ .x = x, .y = y };
            if (point.in(self.rect)) {
                const i = self.pixOffset(x, y);
                const c1 = Color.Gray16Model.convert(c).gray16;
                self.pix[i + 0] = @truncate(u8, c1.y >> 8);
                self.pix[i + 1] = @truncate(u8, c1.y);
            }
        }

        pub fn subImage(self: Gray16, n: Rectangle) ?Image {
            const r = n.intersect(self.rect);
            if (r.empty()) return null;
            const i = self.pixOffset(r.min.x, r.min.y);
            return Image{
                .gray16 = Gray16{
                    .pix = self.pix[i..],
                    .stride = self.stride,
                    .rect = r,
                },
            };
        }

        pub fn @"opaque"(self: Gray16) bool {
            return true;
        }
    };

    pub const CMYK = struct {
        pix: []u8,
        stride: isize,
        rect: Rectangle,

        pub fn init(a: *std.mem.Allocator, r: Rectangle) !CMYK {
            return CMYK{
                .pix = try createPix(a, 4, r, "CMYK"),
                .stride = 4 * r.dx(),
                .rect = r,
            };
        }

        pub fn pixOffset(self: CMYK, x: isize, y: isize) usize {
            const v = (y - self.rect.min.y) * self.stride + (x - self.rect.min.x) * 4;
            return @intCast(usize, v);
        }

        pub fn at(self: CMYK, x: isize, y: isize) Color {
            const point = Point{ .x = x, .y = y };
            if (!point.in(self.rect)) return .{ .cMYK = .{} };
            const i = self.pixOffset(x, y);
            const s = self.pix[i .. i + 4];
            return Color{
                .cMYK = .{
                    .c = s[0],
                    .m = s[1],
                    .y = s[2],
                    .k = s[3],
                },
            };
        }

        pub fn set(self: CMYK, x: isize, y: isize, c: Color) void {
            const point = Point{ .x = x, .y = y };
            if (point.in(self.rect)) {
                const i = self.pixOffset(x, y);
                const c1 = Color.CMYKModel.convert(c).cMYK;
                var s = self.pix[i .. i + 4];
                s[0] = c1.c;
                s[1] = c1.y;
                s[2] = c1.m;
                s[3] = c1.k;
            }
        }

        pub fn subImage(self: CMYK, n: Rectangle) ?Image {
            const r = n.intersect(self.rect);
            if (r.empty()) return null;
            const i = self.pixOffset(r.min.x, r.min.y);
            return Image{
                .cmyk = CMYK{
                    .pix = self.pix[i..],
                    .stride = self.stride,
                    .rect = r,
                },
            };
        }

        pub fn @"opaque"(self: CMYK) bool {
            return true;
        }
    };

    pub const YCbCr = struct {
        y: []u8 = undefined,
        cb: []u8 = undefined,
        cr: []u8 = undefined,
        sub_sample_ration: SusampleRatio = .Ratio444,
        ystride: isize = 0,
        cstride: isize = 0,
        rect: Rectangle = Rectangle.zero(),

        const SusampleRatio = enum {
            Ratio444,
            Ratio422,
            Ratio420,
            Ratio440,
            Ratio411,
            Ratio410,
        };

        pub fn init(a: *std.mem.Allocator, r: Rectangle, ratio: SusampleRatio) !YCbCr {
            const x = yCbCrSize(r, ratio);
            const total_length = geom.add2NonNeg(
                geom.mul3NonNeg(1, x.w, x.h),
                geom.mul3NonNeg(2, x.cw, x.ch),
            );
            if (total_length < 0) {
                return error.HugeOrNegativeRectange;
            }
            const i_0 = @intCast(usize, x.w * x.h + 0 * x.cw * x.ch);
            const i_1 = @intCast(usize, x.w * x.h + 1 * x.cw * x.ch);
            const i_2 = @intCast(usize, x.w * x.h + 2 * x.cw * x.ch);
            var b = try a.alloc(u8, i_2);
            return YCbCr{
                .y = b[0..i_0],
                .cb = b[0..i_1],
                .cr = b[0..i_2],
                .sub_sample_ration = ratio,
                .ystride = x.w,
                .cstride = x.cw,
                .rect = r,
            };
        }

        pub fn at(self: YCbCr, x: isize, y: isize) Color {
            const point = Point{ .x = x, .y = y };
            if (!point.in(self.rect)) return Color{
                .yCbCr = .{},
            };
            const yi = self.yOffset(x, y);
            const ci = self.cOffset(x, y);
            return Color{
                .yCbCr = .{
                    .y = self.y[yi],
                    .cb = self.cb[ci],
                    .cr = self.cr[ci],
                },
            };
        }

        pub fn yOffset(self: YCbCr, x: isize, y: isize) usize {
            const v = (y - self.rect.min.y) * self.ystride + (x - self.rect.min.x);
            return std.math.absCast(v);
        }

        pub fn cOffset(self: YCbCr, x: isize, y: isize) usize {
            return switch (self.sub_sample_ration) {
                .Ratio444 => {
                    const v = (y - self.rect.min.y) * self.cstride + (x - self.rect.min.x);
                    return std.math.absCast(v);
                },
                .Ratio422 => {
                    const v = (y - self.rect.min.y) * self.cstride + (@divTrunc(x, 2) - @divTrunc(self.rect.min.x, 2));
                    return std.math.absCast(v);
                },
                .Ratio420 => {
                    const v = (@divTrunc(y, 2) - @divTrunc(self.rect.min.y, 2)) * self.cstride + (@divTrunc(x, 2) - @divTrunc(self.rect.min.x, 2));
                    return std.math.absCast(v);
                },
                .Ratio440 => {
                    const v = (@divTrunc(y, 2) - @divTrunc(self.rect.min.y, 2)) * self.cstride + (x - self.rect.min.x);
                    return std.math.absCast(v);
                },
                .Ratio411 => {
                    const v = (y - self.rect.min.y) * self.cstride + (@divTrunc(x, 4) - @divTrunc(self.rect.min.x, 4));
                    return std.math.absCast(v);
                },
                .Ratio410 => {
                    const v = (@divTrunc(y, 2) - @divTrunc(self.rect.min.y, 2)) * self.cstride + (@divTrunc(x, 4) - @divTrunc(self.rect.min.x, 4));
                    return std.math.absCast(v);
                },
            };
        }

        pub fn subImage(self: YCbCr, n: Rectangle) ?Image {
            const r = n.intersect(self.rect);
            if (r.empty()) return Image{
                .yCbCr = .{},
            };
            const yi = self.yOffset(r.min.x, r.min.y);
            const ci = self.cOffset(r.min.x, r.min.y);
            return Image{
                .yCbCr = YCbCr{
                    .y = self.y[yi..],
                    .cb = self.cb[ci..],
                    .cr = self.cr[ci..],
                    .sub_sample_ration = self.sub_sample_ration,
                    .ystride = self.ystride,
                    .cstride = self.cstride,
                    .rect = r,
                },
            };
        }

        pub fn @"opaque"(self: YCbCr) bool {
            return true;
        }

        const yrs = struct {
            w: isize,
            h: isize,
            cw: isize,
            ch: isize,
        };

        fn yCbCrSize(r: Rectangle, ratio: SusampleRatio) yrs {
            const w = r.dx();
            const h = r.dy();
            var x = yrs{
                .w = r.dx(),
                .h = r.dy(),
                .cw = 0,
                .ch = 0,
            };
            switch (ratio) {
                .Ratio444 => {
                    x.cw = x.w;
                    x.ch = x.h;
                },
                .Ratio422 => {
                    x.cw = @divTrunc(r.max.x + 1, 2) - @divTrunc(r.min.x, 2);
                    x.ch = x.h;
                },
                .Ratio420 => {
                    x.cw = @divTrunc((r.max.x + 1), 2) - @divTrunc(r.min.x, 2);
                    x.ch = @divTrunc((r.max.y + 1), 2) - @divTrunc(r.min.y, 2);
                },
                .Ratio440 => {
                    x.cw = x.w;
                    x.ch = @divTrunc((r.max.y + 1), 2) - @divTrunc(r.min.y, 2);
                },
                .Ratio411 => {
                    x.cw = @divTrunc((r.max.x + 3), 4) - @divTrunc(r.min.x, 4);
                    x.ch = x.h;
                },
                .Ratio410 => {
                    x.cw = @divTrunc((r.max.x + 3), 4) - @divTrunc(r.min.x, 4);
                    x.ch = @divTrunc((r.max.y + 1), 2) - @divTrunc(r.min.y, 2);
                },
            }
            return x;
        }
    };

    pub const NYCbCrA = struct {
        pix: []u8,
        stride: isize,
        rect: Rectangle,
    };
};

fn cmp(cm: Color.Model, c0: Color, c1: Color) bool {
    // std.debug.print("\nc0={any} c1={any}\n", .{ c0, c1 });
    const v0 = cm.convert(c0).toValue();
    const v1 = cm.convert(c1).toValue();
    // std.debug.print("\nv0={any} v1={any}\n", .{ v0, v1 });
    return v0.eq(v1);
}

// === image TEST
test "Image" {
    const AllocationError = error{
        OutOfMemory,
    };
    const initImage = struct {
        init: fn () AllocationError!Image,

        fn rgba() !Image {
            return Image{
                .rgba = try Image.RGBA.init(testing.allocator, Rectangle.init(0, 0, 10, 10)),
            };
        }

        fn rgba64() !Image {
            return Image{
                .rgba64 = try Image.RGBA64.init(testing.allocator, Rectangle.init(0, 0, 10, 10)),
            };
        }
        fn nrgba() !Image {
            return Image{
                .nrgba = try Image.NRGBA.init(testing.allocator, Rectangle.init(0, 0, 10, 10)),
            };
        }
        fn nrgba64() !Image {
            return Image{
                .nrgba64 = try Image.NRGBA64.init(testing.allocator, Rectangle.init(0, 0, 10, 10)),
            };
        }

        fn alpha() !Image {
            return Image{
                .alpha = try Image.Alpha.init(testing.allocator, Rectangle.init(0, 0, 10, 10)),
            };
        }

        fn alpha16() !Image {
            return Image{
                .alpha16 = try Image.Alpha16.init(testing.allocator, Rectangle.init(0, 0, 10, 10)),
            };
        }
        fn gray() !Image {
            return Image{
                .gray = try Image.Gray.init(testing.allocator, Rectangle.init(0, 0, 10, 10)),
            };
        }
        fn gray16() !Image {
            return Image{
                .gray16 = try Image.Gray16.init(testing.allocator, Rectangle.init(0, 0, 10, 10)),
            };
        }
    };
    const testImages = [_]initImage{
        .{ .init = initImage.rgba },
        .{ .init = initImage.rgba64 },
        .{ .init = initImage.nrgba },
        .{ .init = initImage.nrgba64 },
        .{ .init = initImage.alpha },
        .{ .init = initImage.alpha16 },
        .{ .init = initImage.gray },
        .{ .init = initImage.gray16 },
    };

    for (testImages) |tc| {
        const m = try tc.init();

        const r = Rectangle.init(0, 0, 10, 10);
        testing.expect(r.eq(m.bounds()));
        testing.expect(cmp(m.colorModel(), Color.Transparent, m.at(6, 3)));

        m.set(6, 3, Color.Opaque);
        testing.expect(cmp(m.colorModel(), Color.Opaque, m.at(6, 3)));

        testing.expect(m.subImage(Rectangle.rect(6, 3, 7, 4)).?.@"opaque"());

        const m2 = m.subImage(Rectangle.rect(3, 2, 9, 8)).?;
        testing.expect(Rectangle.rect(3, 2, 9, 8).eq(m2.bounds()));

        testing.expect(cmp(m2.colorModel(), Color.Opaque, m2.at(6, 3)));
        testing.expect(cmp(m2.colorModel(), Color.Transparent, m2.at(3, 3)));
        m2.set(3, 3, Color.Opaque);
        testing.expect(cmp(m2.colorModel(), Color.Opaque, m2.at(3, 3)));

        _ = m2.subImage(Rectangle.rect(0, 0, 0, 0));
        _ = m2.subImage(Rectangle.rect(10, 0, 10, 0));
        _ = m2.subImage(Rectangle.rect(0, 10, 0, 10));
        _ = m2.subImage(Rectangle.rect(10, 10, 10, 10));
        testing.allocator.free(m.get_pix());
    }
}

test "TestYCbCr" {
    const rects = [_]Rectangle{
        Rectangle.rect(0, 0, 16, 16),
        Rectangle.rect(1, 0, 16, 16),
        Rectangle.rect(0, 1, 16, 16),
        Rectangle.rect(1, 1, 16, 16),
        Rectangle.rect(1, 1, 15, 16),
        Rectangle.rect(1, 1, 16, 15),
        Rectangle.rect(1, 1, 15, 15),
        Rectangle.rect(2, 3, 14, 15),
        Rectangle.rect(7, 0, 7, 16),
        Rectangle.rect(0, 8, 16, 8),
        Rectangle.rect(0, 0, 10, 11),
        Rectangle.rect(5, 6, 16, 16),
        Rectangle.rect(7, 7, 8, 8),
        Rectangle.rect(7, 8, 8, 9),
        Rectangle.rect(8, 7, 9, 8),
        Rectangle.rect(8, 8, 9, 9),
        Rectangle.rect(7, 7, 17, 17),
        Rectangle.rect(8, 8, 17, 17),
        Rectangle.rect(9, 9, 17, 17),
        Rectangle.rect(10, 10, 17, 17),
    };

    const sample_rations = [_]Image.YCbCr.SusampleRatio{
        .Ratio444,
        .Ratio422,
        .Ratio420,
        .Ratio440,
        .Ratio411,
        .Ratio410,
    };

    const deltas = [_]Point{
        Point.init(0, 0),
        Point.init(1000, 1001),
        Point.init(5001, -400),
        Point.init(-701, -801),
    };

    for (rects) |r, i| {
        for (sample_rations) |ratio| {
            for (deltas) |delta| {
                try testYCrBrColor(r, ratio, delta);
            }
        }
    }
}

fn testYCrBrColor(r: Rectangle, ratio: Image.YCbCr.SusampleRatio, delta: Point) !void {
    const r1 = r.add(delta);
    var a = std.heap.ArenaAllocator.init(testing.allocator);
    defer a.deinit();

    const m = try Image.YCbCr.init(&a.allocator, r1, ratio);

    // Test that the image buffer is reasonably small even if (delta.X, delta.Y)
    // is far from the origin.
    testing.expect(m.y.len < (100 * 100));

    // Initialize m's pixels. For 422 and 420 subsampling, some of the Cb and Cr elements
    // will be set multiple times. That's OK. We just want to avoid a uniform image.
    var y = r1.min.y;
    while (y < r1.min.y) : (y += 1) {
        var x = r1.min.x;
        while (x < r1.min.x) : (x += 1) {
            const yi = m.yOffset(x, y);
            const ci = m.cOffset(x, y);
            m.y[@intCast(usize, yi)] = @intCast(u8, 16 * y + x);
            m.cb[@intCast(usize, ci)] = @intCast(u8, y + 16 * x);
            m.cr[@intCast(usize, ci)] = @intCast(u8, y + 16 * x);
        }
    }

    // Make various sub-images of m.
    var y0 = delta.y + 3;
    while (y0 < delta.y + 7) : (y0 += 1) {
        var y1 = delta.y + 8;
        while (y1 < delta.y + 13) : (y1 += 1) {
            var x0 = delta.x + 3;
            while (x0 < delta.x + 7) : (x0 += 1) {
                var x1 = delta.x + 8;
                while (x1 < delta.x + 13) : (x1 += 1) {
                    const sub_rect = Rectangle.rect(x0, y0, x1, y1);
                    const sub = m.subImage(sub_rect).?.yCbCr;

                    // For each point in the sub-image's bounds, check that m.At(x, y) equals sub.At(x, y).
                    var yn = sub.rect.min.y;
                    while (yn < sub.rect.max.y) : (yn += 1) {
                        var x = sub.rect.min.x;
                        while (x < sub.rect.max.x) : (x += 1) {
                            const c0 = m.at(x, yn);
                            const c1 = sub.at(x, yn);
                            testing.expectEqual(c0.toValue(), c1.toValue());
                        }
                    }
                }
            }
        }
    }
}
// === image TEST

