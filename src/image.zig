const geom = @import("zig");
const std = @import("std");
const testing = std.testing;
const print = std.debug.print;
const meta = std.meta;

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
        pub fn rgba(m: Color) Color {
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

        pub fn rgba64(m: Color) Color {
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

        pub fn nrgba(m: Color) Color {
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

        pub fn nrgba64(m: Color) Color {
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

        pub fn alpha(m: Color) Color {
            return switch (m) {
                .alpha => m,
                else => {
                    const c = m.toValue();
                    const model = Alpha{ .a = @intCast(u8, c.a >> 8) };
                    return Color{ .alpha = model };
                },
            };
        }

        pub fn alpha16(m: Color) Color {
            return switch (m) {
                .alpha16 => m,
                else => {
                    const c = m.toValue();
                    const model = Alpha16{ .a = @intCast(u16, c.a) };
                    return Color{ .alpha16 = model };
                },
            };
        }

        pub fn gray(m: Color) Color {
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

        pub fn gray16(m: Color) Color {
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

        pub fn yCbCr(m: Color) Color {
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

        pub fn nYCbCrA(m: Color) Color {
            return switch (m) {
                .nYCbCrA => m,
                .yCbCr => |c| .{
                    .nYCbCrA = .{
                        .y = c,
                        .a = 0xff,
                    },
                },
                else => {
                    var v = m.toValue();
                    if (v.a != 0) {
                        v.r = @divTrunc(v.r * 0xffff, v.a);
                        v.g = @divTrunc(v.g * 0xffff, v.a);
                        v.b = @divTrunc(v.b * 0xffff, v.a);
                    }
                    const y = rgbToYCbCr(.{
                        .r = @intCast(u8, v.r >> 8),
                        .g = @intCast(u8, v.g >> 8),
                        .b = @intCast(u8, v.b >> 8),
                    });
                    return Color{
                        .nYCbCrA = .{
                            .y = y,
                            .a = @intCast(u8, v.a >> 8),
                        },
                    };
                },
            };
        }

        pub fn cmyk(c: Color) Color {
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

    pub const RGBAModel = Model.rgba;
    pub const RGBA64Model = Model.rgba64;
    pub const NRGBAModel = Model.nrgba;
    pub const NRGBA64Model = Model.nrgba64;
    pub const AlphaModel = Model.alpha;
    pub const Alpha16Model = Model.alpha16;
    pub const GrayModel = Model.gray;
    pub const Gray16Model = Model.gray16;
    pub const YCbCrModel = Model.yCbCr;
    pub const NYCbCrAModel = Model.nYCbCrA;
    pub const CMYKModel = Model.cmyk;

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
        y: YCbCr = .{},
        a: u8 = 0,

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
        colors: []Color = undefined,

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
            try testing.expectEqual(want, got);
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
                    try testing.expectEqual(o, v1);
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
                try testing.expectEqual(v1, v2);
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
        try ytest.eq(c0, c1);
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
        try ytest.eq(c0, c1);
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
        try ytest.eq(c0, c1);
    }
}
const ytest = struct {
    fn delta(x: u8, y: u8) u8 {
        if (x >= y) {
            return x - y;
        }
        return y - x;
    }

    fn eq(c0: Color, c1: Color) !void {
        try testing.expectEqual(c0.toValue(), c1.toValue());
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
                    try testing.expectEqual(v0, v2);
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
                    try testing.expectEqual(v2, v3);
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
        try ytest.eq(v0, v1);
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
        try testing.expectEqual(i, j);
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
    try ytest.eq(want, got.?);
}

pub const Config = struct {
    model: color.Model,
    width: isize,
    height: isize,
};

/// A Point is an X, Y coordinate pair. The axes increase right and down.
pub const Point = struct {
    x: isize = 0,
    y: isize = 0,

    pub fn format(self: Point, actual: []const u8, opts: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("({},{})", .{ self.x, self.y });
    }

    pub fn init(x: isize, y: isize) Point {
        return Point{ .x = x, .y = y };
    }

    pub fn add(p: Point, q: Point) Point {
        return Point{ .x = p.x + q.x, .y = p.y + q.y };
    }

    pub fn sub(p: Point, q: Point) Point {
        return Point{ .x = p.x - q.x, .y = p.y - q.y };
    }

    pub fn mul(p: Point, q: Point) Point {
        return Point{ .x = p.x * q.x, .y = p.y * q.y };
    }

    pub fn div(p: Point, q: Point) Point {
        return Point{ .x = @divExact(p.x, q.x), .y = @divExact(p.y, q.y) };
    }

    pub fn in(p: Point, r: Rectangle) bool {
        return r.min.x <= p.x and p.x < r.max.x and r.min.y <= p.y and p.y < r.max.y;
    }

    pub fn mod(p: Point, r: Rectangle) Point {
        const w = r.dx();
        const h = r.dy();
        const point = p.sub(r.min);
        var x = @mod(point.x, w);
        if (x < 0) {
            x += w;
        }
        var y = @mod(point.y, h);
        if (y < 0) {
            y += h;
        }
        const np = Point.init(x, y);
        return np.add(r.min);
    }

    pub fn eq(p: Point, q: Point) bool {
        return p.x == q.x and p.y == q.y;
    }
};

pub const Rectangle = struct {
    min: Point = Point{},
    max: Point = Point{},

    pub fn format(self: Rectangle, actual: []const u8, opts: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{}-{}", .{ self.min, self.max });
    }

    pub fn init(x0: isize, y0: isize, x1: isize, y1: isize) Rectangle {
        return Rectangle{
            .min = Point{
                .x = x0,
                .y = y0,
            },
            .max = Point{
                .x = x1,
                .y = y1,
            },
        };
    }

    pub fn rect(x0: isize, y0: isize, x1: isize, y1: isize) Rectangle {
        var r = Rectangle{
            .min = Point{
                .x = x0,
                .y = y0,
            },
            .max = Point{
                .x = x1,
                .y = y1,
            },
        };
        if (x0 > x1) {
            const x = x0;
            r.min.x = x1;
            r.max.x = x;
        }
        if (y0 > y1) {
            const y = y0;
            r.min.y = y1;
            r.max.y = y;
        }
        return r;
    }

    /// dx returns r's width.
    pub fn dx(r: Rectangle) isize {
        return r.max.x - r.min.x;
    }

    pub fn zero() Rectangle {
        return Rectangle.init(0, 0, 0, 0);
    }

    /// dy returns r's height.
    pub fn dy(r: Rectangle) isize {
        return r.max.y - r.min.y;
    }

    /// size returns r's width and height.
    pub fn size(r: Rectangle) Point {
        return Point{ .x = r.dx(), .y = r.dy() };
    }

    /// eEmpty reports whether the rectangle contains no points.
    pub fn empty(r: Rectangle) bool {
        return (r.min.x >= r.max.x) or (r.min.y >= r.max.y);
    }

    pub fn add(r: Rectangle, p: Point) Rectangle {
        return Rectangle{
            .min = Point{ .x = r.min.x + p.x, .y = r.min.y + p.y },
            .max = Point{ .x = r.max.x + p.x, .y = r.max.y + p.y },
        };
    }

    pub fn sub(r: Rectangle, p: Point) Rectangle {
        return Rectangle{
            .min = Point{ .x = r.min.x - p.x, .y = r.min.y - p.y },
            .max = Point{ .x = r.max.x - p.x, .y = r.max.y - p.y },
        };
    }

    /// Inset returns the rectangle r inset by n, which may be negative. If either
    /// of r's dimensions is less than 2*n then an empty rectangle near the center
    /// of r will be returned.
    pub fn inset(r: Rectangle, n: isize) Rectangle {
        var x0 = r.min.x;
        var x1 = r.min.x;
        if (r.dx() < 2 * n) {
            x0 = @divExact((r.min.x + r.max.x), 2);
            x1 = x0;
        } else {
            x0 += n;
            x1 -= n;
        }
        var y0 = r.min.y;
        var y1 = r.max.y;
        if (r.dy() < 2 * n) {
            y0 = @divExact((r.min.y + r.max.y), 2);
            y1 = y0;
        } else {
            y0 += n;
            y1 -= n;
        }
        return Rectangle.init(x0, y0, x1, y1);
    }

    /// Intersect returns the largest rectangle contained by both r and s. If the
    /// two rectangles do not overlap then the zero rectangle will be returned.
    pub fn intersect(r: Rectangle, s: Rectangle) Rectangle {
        var x0 = r.min.x;
        var y0 = r.min.y;
        var x1 = r.max.x;
        var y1 = r.max.y;
        if (x0 < s.min.x) {
            x0 = s.min.x;
        }
        if (y0 < s.min.y) {
            y0 = s.min.y;
        }
        if (x1 > s.max.x) {
            x1 = s.max.x;
        }
        if (y1 > s.max.y) {
            y1 = s.max.y;
        }
        const rec = Rectangle.init(x0, y0, x1, y1);
        if (rec.empty()) {
            return Rectangle.zero();
        }
        return rec;
    }

    /// Union returns the smallest rectangle that contains both r and s.
    pub fn runion(r: Rectangle, s: Rectangle) Rectangle {
        if (r.empty()) {
            return s;
        }
        if (s.empty()) {
            return r;
        }
        var a = [_]isize{ r.min.x, r.min.y, r.max.x, r.max.y };
        if (a[0] > s.min.x) {
            a[0] = s.min.x;
        }
        if (a[1] > s.min.y) {
            a[1] = s.min.y;
        }
        if (a[2] < s.max.x) {
            a[2] = s.max.x;
        }
        if (a[3] < s.max.y) {
            a[3] = s.max.y;
        }
        return Rectangle.init(a[0], a[1], a[2], a[3]);
    }

    pub fn eq(r: Rectangle, s: Rectangle) bool {
        return r.max.eq(s.max) and r.min.eq(s.min) or r.empty() and s.empty();
    }

    pub fn overlaps(r: Rectangle, s: Rectangle) bool {
        return !r.empty() and !s.empty() and
            r.min.x < s.max.x and s.min.x < r.max.x and r.min.y < s.max.y and s.min.y < r.max.y;
    }

    pub fn in(r: Rectangle, s: Rectangle) bool {
        if (r.empty()) {
            return true;
        }
        return s.min.x <= r.min.x and r.max.x <= s.max.x and
            s.min.y <= r.min.y and r.max.y <= s.max.y;
    }

    pub fn canon(r: Rectangle) Rectangle {
        var x0 = r.min.x;
        var x1 = r.max.x;
        if (r.max.x < r.min.x) {
            const x = r.min.x;
            x0 = r.max.x;
            x1 = x;
        }
        var y0 = r.min.x;
        var y1 = r.min.x;
        if (r.min.y < r.max.y) {
            const y = y0;
            y0 = y1;
            y1 = y;
        }
        return Rectangle.init(x0, y0, x1, y1);
    }

    pub fn at(r: Rectangle, x: isize, y: isize) color.Color {
        var p = Point{ .x = x, .y = y };
        if (p.in(r)) {
            return color.Opaque;
        }
        return color.Transparent;
    }

    pub fn bounds(r: Rectangle) Rectangle {
        return r;
    }

    pub fn colorModel(r: Rectangle) color.Model {
        return color.Alpha16Model;
    }
};
test "Rectangle" {
    const check = struct {
        fn in(f: Rectangle, g: Rectangle) bool {
            if (!f.in(g)) {
                return false;
            }
            var y = f.min.y;
            while (y < f.max.y) {
                var x = f.min.x;
                while (x < f.max.x) {
                    var p = Point.init(x, y);
                    if (!p.in(g)) {
                        return false;
                    }
                    x += 1;
                }
                y += 1;
            }
            return true;
        }
    };
    const rectangles = [_]Rectangle{
        Rectangle.rect(0, 0, 10, 10),
        Rectangle.rect(10, 0, 20, 10),
        Rectangle.rect(1, 2, 3, 4),
        Rectangle.rect(4, 6, 10, 10),
        Rectangle.rect(2, 3, 12, 5),
        Rectangle.rect(-1, -2, 0, 0),
        Rectangle.rect(-1, -2, 4, 6),
        Rectangle.rect(-10, -20, 30, 40),
        Rectangle.rect(8, 8, 8, 8),
        Rectangle.rect(88, 88, 88, 88),
        Rectangle.rect(6, 5, 4, 3),
    };
    for (rectangles) |r| {
        for (rectangles) |s| {
            const got = r.eq(s);
            const want = check.in(r, s) and check.in(s, r);
            try testing.expectEqual(got, want);
        }
    }
    for (rectangles) |r| {
        for (rectangles) |s| {
            const a = r.intersect(s);
            try testing.expect(check.in(a, r));
            try testing.expect(check.in(a, s));
            const is_zero = a.eq(Rectangle.zero());
            const overlaps = r.overlaps(s);
            try testing.expect(is_zero != overlaps);
            const larger_than_a = [_]Rectangle{
                Rectangle.init(
                    a.min.x - 1,
                    a.min.y,
                    a.max.x,
                    a.max.y,
                ),
                Rectangle.init(
                    a.min.x,
                    a.min.y - 1,
                    a.max.x,
                    a.max.y,
                ),
                Rectangle.init(
                    a.min.x,
                    a.min.y,
                    a.max.x + 1,
                    a.max.y,
                ),
                Rectangle.init(
                    a.min.x,
                    a.min.y,
                    a.max.x,
                    a.max.y + 1,
                ),
            };
            for (larger_than_a) |b| {
                if (b.empty()) {
                    continue;
                }
                try testing.expect(!(check.in(b, r) and check.in(b, s)));
            }
        }
    }

    for (rectangles) |r| {
        for (rectangles) |s| {
            const a = r.runion(s);
            try testing.expect(check.in(r, a));
            try testing.expect(check.in(s, a));
            if (a.empty()) {
                continue;
            }
            const smaller_than_a = [_]Rectangle{
                Rectangle.init(
                    a.min.x + 1,
                    a.min.y,
                    a.max.x,
                    a.max.y,
                ),
                Rectangle.init(
                    a.min.x,
                    a.min.y + 1,
                    a.max.x,
                    a.max.y,
                ),
                Rectangle.init(
                    a.min.x,
                    a.min.y,
                    a.max.x - 1,
                    a.max.y,
                ),
                Rectangle.init(
                    a.min.x,
                    a.min.y,
                    a.max.x,
                    a.max.y - 1,
                ),
            };
            for (smaller_than_a) |b| {
                try testing.expect(!(check.in(r, b) and check.in(s, b)));
            }
        }
    }
}

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
    nYCbCrA: NYCbCrA,
    paletted: Paletted,

    pub fn convert(self: Image, c: Color) ?Color {
        return switch (self) {
            .rgba => Color.RGBAModel(c),
            .rgba64 => Color.RGBA64Model(c),
            .nrgba => Color.RGBA64Model(c),
            .nrgba64 => Color.NRGBA64Model(c),
            .alpha => Color.AlphaModel(c),
            .alpha16 => Color.Alpha16Model(c),
            .gray => Color.GrayModel(c),
            .gray16 => Color.Gray16Model(c),
            .cmyk => Color.CMYKModel(c),
            .yCbCr => Color.YCbCrModel(c),
            .nYCbCrA => Color.NYCbCrAModel(c),
            .paletted => |p| p.palette.convert(c),
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
            .nYCbCrA => |i| i.y.rect,
            .paletted => |i| i.rect,
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
            else => unreachable,
        };
    }

    pub fn at(self: Image, x: isize, y: isize) ?Color {
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
            .nYCbCrA => |i| i.at(x, y),
            .paletted => |i| i.at(x, y),
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
            .paletted => |i| i.set(x, y, c),
            else => unreachable,
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
            .nYCbCrA => |i| i.subImage(r),
            .paletted => |i| i.subImage(r),
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
            .yCbCr => |i| i.@"opaque"(),
            .nYCbCrA => |i| i.@"opaque"(),
            .paletted => |i| i.@"opaque"(),
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
                const c1 = Color.RGBAModel(c).toValue();
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

    fn pixelBufferLength(bytesPerPixel: isize, r: Rectangle, imageTypeName: []const u8) usize {
        const totalLength = mul3NonNeg(bytesPerPixel, r.dx(), r.dy());
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
                const c1 = Color.RGBA64Model(c).toValue();
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
                const c1 = Color.NRGBAModel(c).toValue();
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
                const c1 = Color.NRGBA64Model(c).toValue();
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
                self.pix[i] = Color.AlphaModel(c).alpha.a;
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
                const c1 = Color.Alpha16Model(c).alpha16;
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
                self.pix[i] = Color.GrayModel(c).gray.y;
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
                const c1 = Color.Gray16Model(c).gray16;
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
                const c1 = Color.CMYKModel(c).cMYK;
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
        sub_sample_ration: SampleRatio = .Ratio444,
        ystride: isize = 0,
        cstride: isize = 0,
        rect: Rectangle = Rectangle.zero(),

        pub const SampleRatio = enum {
            Ratio444,
            Ratio422,
            Ratio420,
            Ratio440,
            Ratio411,
            Ratio410,
        };

        pub fn init(a: *std.mem.Allocator, r: Rectangle, ratio: SampleRatio) !YCbCr {
            const x = yCbCrSize(r, ratio);
            const total_length = add2NonNeg(
                mul3NonNeg(1, x.w, x.h),
                mul3NonNeg(2, x.cw, x.ch),
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

        pub fn yCbCrSize(r: Rectangle, ratio: SampleRatio) yrs {
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
        y: YCbCr,
        pix: []u8 = undefined,
        a: []u8 = undefined,
        astride: isize = 0,

        pub fn init(a: *std.mem.Allocator, r: Rectangle, ratio: YCbCr.SampleRatio) !NYCbCrA {
            const x = YCbCr.yCbCrSize(r, ratio);
            const total_length = add2NonNeg(mul3NonNeg(2, x.w, x.h), mul3NonNeg(2, x.cw, x.ch));
            if (total_length < 0) return error.RectangleHugeOrNegativeDimension;

            const i_0 = @intCast(usize, 1 * x.w * x.h + 0 * x.cw * x.ch);
            const i_1 = @intCast(usize, 1 * x.w * x.h + 1 * x.cw * x.ch);
            const i_2 = @intCast(usize, 1 * x.w * x.h + 2 * x.cw * x.ch);
            const i_3 = @intCast(usize, 2 * x.w * x.h + 2 * x.cw * x.ch);
            var b = try a.alloc(u8, i_3);
            return NYCbCrA{
                .y = .{
                    .y = b[0..i_0],
                    .cb = b[i_0..i_1],
                    .cr = b[i_1..i_2],
                    .sub_sample_ration = ratio,
                    .ystride = x.w,
                    .cstride = x.h,
                    .rect = r,
                },
                .a = b[i_2..],
                .astride = x.w,
            };
        }

        pub fn at(self: NYCbCrA, x: isize, y: isize) Color {
            const point = Point{ .x = x, .y = y };
            if (!point.in(self.y.rect)) return Color{
                .nYCbCrA = .{},
            };
            const yi = self.y.yOffset(x, y);
            const ci = self.y.cOffset(x, y);
            const ai = self.aOffset(x, y);
            return Color{
                .nYCbCrA = .{
                    .y = .{
                        .y = self.y.y[yi],
                        .cb = self.y.cb[ci],
                        .cr = self.y.cr[ci],
                    },
                    .a = self.a[ai],
                },
            };
        }

        pub fn aOffset(self: NYCbCrA, x: isize, y: isize) usize {
            const v = (y - self.y.rect.min.y) * self.astride + (x - self.y.rect.min.x);
            return std.math.absCast(v);
        }

        pub fn subImage(self: NYCbCrA, n: Rectangle) ?Image {
            const r = n.intersect(self.y.rect);
            if (r.empty()) return Image{
                .nYCbCrA = .{
                    .y = .{
                        .sub_sample_ration = self.y.sub_sample_ration,
                    },
                },
            };
            const yi = self.y.yOffset(r.min.x, r.min.y);
            const ci = self.y.cOffset(r.min.x, r.min.y);
            const ai = self.aOffset(r.min.x, r.min.y);
            return Image{
                .nYCbCrA = .{
                    .y = YCbCr{
                        .y = self.y.y[yi..],
                        .cb = self.y.cb[ci..],
                        .cr = self.y.cr[ci..],
                        .sub_sample_ration = self.y.sub_sample_ration,
                        .ystride = self.y.ystride,
                        .cstride = self.y.cstride,
                        .rect = r,
                    },
                    .a = self.a[ai..],
                    .astride = self.astride,
                },
            };
        }

        pub fn @"opaque"(self: NYCbCrA) bool {
            return true;
        }
    };

    // Paletted is an in-memory image of uint8 indices into a given palette.
    pub const Paletted = struct {
        pix: []u8,
        stride: isize,
        rect: Rectangle,
        palette: Color.Palette,

        pub fn init(a: *std.mem.Allocator, r: Rectangle, p: Color.Palette) !Paletted {
            return Paletted{
                .pix = try createPix(a, 1, r, "Paletted"),
                .stride = 1 * r.dx(),
                .rect = r,
                .palette = p,
            };
        }

        pub fn pixOffset(self: Paletted, x: isize, y: isize) usize {
            const v = (y - self.rect.min.y) * self.stride + (x - self.rect.min.x) * 1;
            return @intCast(usize, v);
        }

        pub fn at(self: Paletted, x: isize, y: isize) ?Color {
            const point = Point{ .x = x, .y = y };
            if (!point.in(self.rect)) return null;
            const i = self.pixOffset(x, y);
            const s = self.pix[i .. i + 4];
            return self.palette.colors[@intCast(usize, self.pix[i])];
        }

        pub fn set(self: Paletted, x: isize, y: isize, c: Color) void {
            const point = Point{ .x = x, .y = y };
            if (point.in(self.rect)) {
                const i = self.pixOffset(x, y);
                self.pix[i] = @truncate(u8, self.palette.index(c));
            }
        }

        pub fn subImage(self: Paletted, r: Rectangle) ?Image {
            const n = r.intersect(self.rect);
            if (r.empty()) return null;
            const i = self.pixOffset(n.min.x, n.min.y);
            return Image{
                .paletted = .{
                    .pix = self.pix[i..],
                    .stride = self.stride,
                    .rect = self.rect.intersect(r),
                    .palette = self.palette,
                },
            };
        }

        pub fn @"opaque"(self: Paletted) bool {
            var present: [256]bool = undefined;
            var i: usize = 0;
            while (i < present.len) : (i += 1) {
                present[i] = false;
            }
            var i_0: isize = 0;
            var i_1: isize = self.rect.dx();
            var y: isize = self.rect.min.y;
            while (y < self.rect.max.y) : (y += 1) {
                for (self.pix[@intCast(usize, i_0)..@intCast(usize, i_1)]) |c| {
                    present[@intCast(usize, c)] = true;
                }
                i_0 += self.stride;
                i_1 += self.stride;
            }
            for (self.palette.colors) |c, x| {
                if (!present[x]) continue;
                const v = c.toValue();
                if (v.a != 0xffff) return false;
            }
            return false;
        }
    };
};

// mul3NonNeg returns (x * y * z), unless at least one argument is negative or
// if the computation overflows the int type, in which case it returns -1.
pub fn mul3NonNeg(x: isize, y: isize, z: isize) isize {
    if ((x < 0) or (y < 0) or (z < 0)) return -1;
    var m = mul64(@intCast(u64, x), @intCast(u64, y));
    if (m.hi != 0) return -1;
    m = mul64(m.lo, @intCast(u64, z));
    if (m.hi != 0) return -1;
    const a = @intCast(isize, m.lo);
    if ((a < 0) or @intCast(u64, a) != m.lo) return -1;
    return a;
}

const mul64Res = struct {
    hi: u64,
    lo: u64,
};

fn mul64(x: u64, y: u64) mul64Res {
    const mask32 = (1 << 32) - 1;
    const x0 = x & mask32;
    const x1 = x >> 32;
    const y0 = y & mask32;
    const y1 = y >> 32;
    const w0 = x0 * y0;
    const t = x1 * y0 + (w0 >> 32);
    var w1 = t & mask32;
    const w2 = t >> 32;
    w1 += x0 * y1;
    const hi = x1 * y1 + w2 + (w1 >> 32);
    var lo: u64 = undefined;
    _ = @mulWithOverflow(u64, x, y, &lo);
    return mul64Res{
        .hi = hi,
        .lo = lo,
    };
}

// add2NonNeg returns (x + y), unless at least one argument is negative or if
// the computation overflows the int type, in which case it returns -1.
pub fn add2NonNeg(x: isize, y: isize) isize {
    if ((x < 0) or (y < 0)) return -1;
    const a = x + y;
    if (a < 0) return -1;
    return a;
}

test "Mul64" {
    const _M64: u64 = (1 << 64) - 1;
    const kase = struct {
        x: u64,
        y: u64,
        want: mul64Res,
    };
    const kases = [_]kase{
        .{
            .x = 1 << 63,
            .y = 2,
            .want = .{
                .hi = 1,
                .lo = 0,
            },
        },
        .{
            .x = 0x3626229738a3b9,
            .y = 0xd8988a9f1cc4a61,
            .want = .{
                .hi = 0x2dd0712657fe8,
                .lo = 0x9dd6a3364c358319,
            },
        },
        .{
            .x = _M64,
            .y = _M64,
            .want = .{
                .hi = _M64 - 1,
                .lo = 1,
            },
        },
    };
    for (kases) |v, i| {
        const r = mul64(v.x, v.y);
        try testing.expectEqual(r, v.want);
    }

    // symetric
    for (kases) |v, i| {
        const r = mul64(v.y, v.x);
        try testing.expectEqual(r, v.want);
    }
}

fn cmp(cm: Image, c0: ?Color, c1: ?Color) bool {
    // std.debug.print("\nc0={any} c1={any}\n", .{ c0, c1 });
    const v0 = cm.convert(c0.?).?.toValue();
    const v1 = cm.convert(c1.?).?.toValue();
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
        try testing.expect(r.eq(m.bounds()));
        try testing.expect(cmp(m, Color.Transparent, m.at(6, 3)));

        m.set(6, 3, Color.Opaque);
        try testing.expect(cmp(m, Color.Opaque, m.at(6, 3)));

        try testing.expect(m.subImage(Rectangle.rect(6, 3, 7, 4)).?.@"opaque"());

        const m2 = m.subImage(Rectangle.rect(3, 2, 9, 8)).?;
        try testing.expect(Rectangle.rect(3, 2, 9, 8).eq(m2.bounds()));

        try testing.expect(cmp(m2, Color.Opaque, m2.at(6, 3)));
        try testing.expect(cmp(m2, Color.Transparent, m2.at(3, 3)));
        m2.set(3, 3, Color.Opaque);
        try testing.expect(cmp(m2, Color.Opaque, m2.at(3, 3)));

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

    const sample_rations = [_]Image.YCbCr.SampleRatio{
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

fn testYCrBrColor(r: Rectangle, ratio: Image.YCbCr.SampleRatio, delta: Point) !void {
    const r1 = r.add(delta);
    var a = std.heap.ArenaAllocator.init(testing.allocator);
    defer a.deinit();

    const m = try Image.YCbCr.init(&a.allocator, r1, ratio);

    // Test that the image buffer is reasonably small even if (delta.X, delta.Y)
    // is far from the origin.
    try testing.expect(m.y.len < (100 * 100));

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
                            try testing.expectEqual(c0.toValue(), c1.toValue());
                        }
                    }
                }
            }
        }
    }
}
// === image TEST

