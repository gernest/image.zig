const testing = @import("std").testing;

/// Color can convert itself to alpha-premultiplied 16-bits per channel RGBA.
/// The conversion may be lossy.
pub const Color = union(enum) {
    rgba: RGBA,
    rgba64: RGBA64,
    nrgba: NRGBA,
    nrgba64: NBRGBA64,
    alpha: Alpha,
    alpha16: Alpha16,
    gray: Gray,
    gray16: Gray16,
    yCbCr: YCbCr,

    pub fn toValue(self: Color) Value {
        return valueFn(self);
    }

    fn valueFn(v: anytype) Value {
        return v.toValue();
    }
};

/// Value is the alpha-premultiplied red, green, blue and alpha values
/// for the color. Each value ranges within [0, 0xffff], but is represented
/// by a uint32 so that multiplying by a blend factor up to 0xffff will not
/// overflow.
///
/// An alpha-premultiplied color component c has been scaled by alpha (a),
/// so has valid values 0 <= c <= a.
pub const Value = struct {
    r: u32 = 0,
    g: u32 = 0,
    b: u32 = 0,
    a: u32 = 0,
};

/// Model can convert any Color to one from its own color model. The conversion
/// may be lossy.
pub const Model = struct {
    convert: fn (c: Color) Color,

    pub fn rgbaModel(m: Color) Color {
        return switch (m) {
            .rgba => m,
            else => {
                const c = m.toValue();
                const model = RGBA{
                    .r = @intCast(u8, c.r >> 8),
                    .g = @intCast(u8, c.g >> 8),
                    .b = @intCast(u8, c.b >> 8),
                    .a = @intCast(u8, c.a >> 8),
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
                    .r = c.r,
                    .g = c.g,
                    .b = c.b,
                    .a = c.a,
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
                        .r = @intCast(u8, c.r >> 8),
                        .g = @intCast(u8, c.g >> 8),
                        .b = @intCast(u8, c.b >> 8),
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
                var r = (c.r * 0xffff) / c.a;
                var g = (c.g * 0xffff) / c.a;
                var b = (c.b * 0xffff) / c.a;
                const model = NRGBA{
                    .r = @intCast(u8, r >> 8),
                    .g = @intCast(u8, g >> 8),
                    .b = @intCast(u8, b >> 8),
                    .a = @intCast(u8, c.rgb.a >> 8),
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
                        .r = c.r,
                        .g = c.g,
                        .b = c.b,
                        .a = 0xff,
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
                var r = (c.r * 0xffff) / c.a;
                var g = (c.g * 0xffff) / c.a;
                var b = (c.b * 0xffff) / c.a;
                const model = NRGBA64{
                    .r = r,
                    .g = g,
                    .b = b,
                    .a = c.a,
                };
                return Color{ .nrgba64 = model };
            },
        };
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
                return Color{ .yCbCr = rgbToYCbCr(m.toValue()) };
            },
        };
    }
};

/// RGBA represents a traditional 32-bit alpha-premultiplied color, having 8
/// bits for each of red, green, blue and alpha.
///
/// An alpha-premultiplied color component C has been scaled by alpha (A), so
/// has valid values 0 <= C <= A.
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

/// RGBA64 represents a 64-bit alpha-premultiplied color, having 16 bits for
/// each of red, green, blue and alpha.
/// An alpha-premultiplied color component C has been scaled by alpha (A), so
/// has valid values 0 <= C <= A.
pub const RGBA64 = struct {
    r: u16,
    g: u16,
    b: u16,
    a: u16,

    fn toValue(c: RGBA64) Value {
        return Value{
            .r = c.r,
            .g = c.g,
            .b = c.b,
            .a = c.a,
        };
    }
};

/// NRGBA represents a non-alpha-premultiplied 32-bit color.
pub const NRGBA = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    fn toColor(c: NBRGBA) Value {
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

pub const NBRGBA64 = struct {
    r: u16,
    g: u16,
    b: u16,
    a: u16,

    fn toColor(c: NBRGBA64) Value {
        var r: u32 = c.r;
        var g: u32 = c.g;
        var b: u32 = c.b;
        var a: u32 = c.a;
        r |= r << 8;
        r *= a;
        r /= 0xffff;
        g |= g << 8;
        g *= a;
        g /= 0xffff;
        b |= b << 8;
        b *= a;
        b /= 0xffff;
        return Value{
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        };
    }
};

/// Alpha represents an 8-bit alpha color.
pub const Alpha = struct {
    a: u8,

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
    a: u16,

    fn toValue(c: Alpha16) Value {
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

/// Gray represents an 8-bit grayscale color.
pub const Gray = struct {
    y: u8,

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
    y: u16,

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

pub const Black = Color{ .gray = Gray{ .y = 0 } };
pub const White = Color{ .gray = Gray{ .y = 0xffff } };
pub const Transparent = Color{ .alpha = Alpha{ .a = 0 } };
pub const Opaque = Color{ .alpha16 = Alpha16{ .a = 0xffff } };

/// sqDiff returns the squared-difference of x and y, shifted by 2 so that
/// adding four of those won't overflow a uint32.
///
/// x and y are both assumed to be in the range [0, 0xffff].
fn sqDiff(x: u32, y: u32) u32 {
    var d: u32 = 0;
    if (x > y) {
        d = x - y;
    } else {
        d = y - x;
    }
    var m: u32 = undefined;
    _ = @mulWithOverflow(u32, d, d, &m);
    return m >> 2;
}

test "sqDiff" {
    const Kase = struct {
        x: u32,
        y: u32,
        diff: u32,
    };
    const kases = [_]Kase{
        .{ .x = 0x0, .y = 0x0, .diff = 0x0 },
        .{ .x = 0x0, .y = 0x1, .diff = 0x0 },
        .{ .x = 0x0, .y = 0x2, .diff = 0x1 },
        .{ .x = 0x0, .y = 0xfffd, .diff = 0x3ffe8002 },
        .{ .x = 0x0, .y = 0xfffe, .diff = 0x3fff0001 },
        .{ .x = 0x0, .y = 0xffff, .diff = 0x3fff8000 },
        .{ .x = 0x0, .y = 0x10000, .diff = 0x0 },
        .{ .x = 0x0, .y = 0x10001, .diff = 0x8000 },
        .{ .x = 0x0, .y = 0x10002, .diff = 0x10001 },
        .{ .x = 0x0, .y = 0xfffffffd, .diff = 0x2 },
        .{ .x = 0x0, .y = 0xfffffffe, .diff = 0x1 },
        .{ .x = 0x0, .y = 0xffffffff, .diff = 0x0 },
        .{ .x = 0x1, .y = 0x0, .diff = 0x0 },
        .{ .x = 0x1, .y = 0x1, .diff = 0x0 },
        .{ .x = 0x1, .y = 0x2, .diff = 0x0 },
        .{ .x = 0x1, .y = 0xfffd, .diff = 0x3ffe0004 },
        .{ .x = 0x1, .y = 0xfffe, .diff = 0x3ffe8002 },
        .{ .x = 0x1, .y = 0xffff, .diff = 0x3fff0001 },
        .{ .x = 0x1, .y = 0x10000, .diff = 0x3fff8000 },
        .{ .x = 0x1, .y = 0x10001, .diff = 0x0 },
        .{ .x = 0x1, .y = 0x10002, .diff = 0x8000 },
        .{ .x = 0x1, .y = 0xfffffffd, .diff = 0x4 },
        .{ .x = 0x1, .y = 0xfffffffe, .diff = 0x2 },
        .{ .x = 0x1, .y = 0xffffffff, .diff = 0x1 },
        .{ .x = 0x2, .y = 0x0, .diff = 0x1 },
        .{ .x = 0x2, .y = 0x1, .diff = 0x0 },
        .{ .x = 0x2, .y = 0x2, .diff = 0x0 },
        .{ .x = 0x2, .y = 0xfffd, .diff = 0x3ffd8006 },
        .{ .x = 0x2, .y = 0xfffe, .diff = 0x3ffe0004 },
        .{ .x = 0x2, .y = 0xffff, .diff = 0x3ffe8002 },
        .{ .x = 0x2, .y = 0x10000, .diff = 0x3fff0001 },
        .{ .x = 0x2, .y = 0x10001, .diff = 0x3fff8000 },
        .{ .x = 0x2, .y = 0x10002, .diff = 0x0 },
        .{ .x = 0x2, .y = 0xfffffffd, .diff = 0x6 },
        .{ .x = 0x2, .y = 0xfffffffe, .diff = 0x4 },
        .{ .x = 0x2, .y = 0xffffffff, .diff = 0x2 },
        .{ .x = 0xfffd, .y = 0x0, .diff = 0x3ffe8002 },
        .{ .x = 0xfffd, .y = 0x1, .diff = 0x3ffe0004 },
        .{ .x = 0xfffd, .y = 0x2, .diff = 0x3ffd8006 },
        .{ .x = 0xfffd, .y = 0xfffd, .diff = 0x0 },
        .{ .x = 0xfffd, .y = 0xfffe, .diff = 0x0 },
        .{ .x = 0xfffd, .y = 0xffff, .diff = 0x1 },
        .{ .x = 0xfffd, .y = 0x10000, .diff = 0x2 },
        .{ .x = 0xfffd, .y = 0x10001, .diff = 0x4 },
        .{ .x = 0xfffd, .y = 0x10002, .diff = 0x6 },
        .{ .x = 0xfffd, .y = 0xfffffffd, .diff = 0x0 },
        .{ .x = 0xfffd, .y = 0xfffffffe, .diff = 0x3fff8000 },
        .{ .x = 0xfffd, .y = 0xffffffff, .diff = 0x3fff0001 },
        .{ .x = 0xfffe, .y = 0x0, .diff = 0x3fff0001 },
        .{ .x = 0xfffe, .y = 0x1, .diff = 0x3ffe8002 },
        .{ .x = 0xfffe, .y = 0x2, .diff = 0x3ffe0004 },
        .{ .x = 0xfffe, .y = 0xfffd, .diff = 0x0 },
        .{ .x = 0xfffe, .y = 0xfffe, .diff = 0x0 },
        .{ .x = 0xfffe, .y = 0xffff, .diff = 0x0 },
        .{ .x = 0xfffe, .y = 0x10000, .diff = 0x1 },
        .{ .x = 0xfffe, .y = 0x10001, .diff = 0x2 },
        .{ .x = 0xfffe, .y = 0x10002, .diff = 0x4 },
        .{ .x = 0xfffe, .y = 0xfffffffd, .diff = 0x8000 },
        .{ .x = 0xfffe, .y = 0xfffffffe, .diff = 0x0 },
        .{ .x = 0xfffe, .y = 0xffffffff, .diff = 0x3fff8000 },
        .{ .x = 0xffff, .y = 0x0, .diff = 0x3fff8000 },
        .{ .x = 0xffff, .y = 0x1, .diff = 0x3fff0001 },
        .{ .x = 0xffff, .y = 0x2, .diff = 0x3ffe8002 },
        .{ .x = 0xffff, .y = 0xfffd, .diff = 0x1 },
        .{ .x = 0xffff, .y = 0xfffe, .diff = 0x0 },
        .{ .x = 0xffff, .y = 0xffff, .diff = 0x0 },
        .{ .x = 0xffff, .y = 0x10000, .diff = 0x0 },
        .{ .x = 0xffff, .y = 0x10001, .diff = 0x1 },
        .{ .x = 0xffff, .y = 0x10002, .diff = 0x2 },
        .{ .x = 0xffff, .y = 0xfffffffd, .diff = 0x10001 },
        .{ .x = 0xffff, .y = 0xfffffffe, .diff = 0x8000 },
        .{ .x = 0xffff, .y = 0xffffffff, .diff = 0x0 },
        .{ .x = 0x10000, .y = 0x0, .diff = 0x0 },
        .{ .x = 0x10000, .y = 0x1, .diff = 0x3fff8000 },
        .{ .x = 0x10000, .y = 0x2, .diff = 0x3fff0001 },
        .{ .x = 0x10000, .y = 0xfffd, .diff = 0x2 },
        .{ .x = 0x10000, .y = 0xfffe, .diff = 0x1 },
        .{ .x = 0x10000, .y = 0xffff, .diff = 0x0 },
        .{ .x = 0x10000, .y = 0x10000, .diff = 0x0 },
        .{ .x = 0x10000, .y = 0x10001, .diff = 0x0 },
        .{ .x = 0x10000, .y = 0x10002, .diff = 0x1 },
        .{ .x = 0x10000, .y = 0xfffffffd, .diff = 0x18002 },
        .{ .x = 0x10000, .y = 0xfffffffe, .diff = 0x10001 },
        .{ .x = 0x10000, .y = 0xffffffff, .diff = 0x8000 },
        .{ .x = 0x10001, .y = 0x0, .diff = 0x8000 },
        .{ .x = 0x10001, .y = 0x1, .diff = 0x0 },
        .{ .x = 0x10001, .y = 0x2, .diff = 0x3fff8000 },
        .{ .x = 0x10001, .y = 0xfffd, .diff = 0x4 },
        .{ .x = 0x10001, .y = 0xfffe, .diff = 0x2 },
        .{ .x = 0x10001, .y = 0xffff, .diff = 0x1 },
        .{ .x = 0x10001, .y = 0x10000, .diff = 0x0 },
        .{ .x = 0x10001, .y = 0x10001, .diff = 0x0 },
        .{ .x = 0x10001, .y = 0x10002, .diff = 0x0 },
        .{ .x = 0x10001, .y = 0xfffffffd, .diff = 0x20004 },
        .{ .x = 0x10001, .y = 0xfffffffe, .diff = 0x18002 },
        .{ .x = 0x10001, .y = 0xffffffff, .diff = 0x10001 },
        .{ .x = 0x10002, .y = 0x0, .diff = 0x10001 },
        .{ .x = 0x10002, .y = 0x1, .diff = 0x8000 },
        .{ .x = 0x10002, .y = 0x2, .diff = 0x0 },
        .{ .x = 0x10002, .y = 0xfffd, .diff = 0x6 },
        .{ .x = 0x10002, .y = 0xfffe, .diff = 0x4 },
        .{ .x = 0x10002, .y = 0xffff, .diff = 0x2 },
        .{ .x = 0x10002, .y = 0x10000, .diff = 0x1 },
        .{ .x = 0x10002, .y = 0x10001, .diff = 0x0 },
        .{ .x = 0x10002, .y = 0x10002, .diff = 0x0 },
        .{ .x = 0x10002, .y = 0xfffffffd, .diff = 0x28006 },
        .{ .x = 0x10002, .y = 0xfffffffe, .diff = 0x20004 },
        .{ .x = 0x10002, .y = 0xffffffff, .diff = 0x18002 },
        .{ .x = 0xfffffffd, .y = 0x0, .diff = 0x2 },
        .{ .x = 0xfffffffd, .y = 0x1, .diff = 0x4 },
        .{ .x = 0xfffffffd, .y = 0x2, .diff = 0x6 },
        .{ .x = 0xfffffffd, .y = 0xfffd, .diff = 0x0 },
        .{ .x = 0xfffffffd, .y = 0xfffe, .diff = 0x8000 },
        .{ .x = 0xfffffffd, .y = 0xffff, .diff = 0x10001 },
        .{ .x = 0xfffffffd, .y = 0x10000, .diff = 0x18002 },
        .{ .x = 0xfffffffd, .y = 0x10001, .diff = 0x20004 },
        .{ .x = 0xfffffffd, .y = 0x10002, .diff = 0x28006 },
        .{ .x = 0xfffffffd, .y = 0xfffffffd, .diff = 0x0 },
        .{ .x = 0xfffffffd, .y = 0xfffffffe, .diff = 0x0 },
        .{ .x = 0xfffffffd, .y = 0xffffffff, .diff = 0x1 },
        .{ .x = 0xfffffffe, .y = 0x0, .diff = 0x1 },
        .{ .x = 0xfffffffe, .y = 0x1, .diff = 0x2 },
        .{ .x = 0xfffffffe, .y = 0x2, .diff = 0x4 },
        .{ .x = 0xfffffffe, .y = 0xfffd, .diff = 0x3fff8000 },
        .{ .x = 0xfffffffe, .y = 0xfffe, .diff = 0x0 },
        .{ .x = 0xfffffffe, .y = 0xffff, .diff = 0x8000 },
        .{ .x = 0xfffffffe, .y = 0x10000, .diff = 0x10001 },
        .{ .x = 0xfffffffe, .y = 0x10001, .diff = 0x18002 },
        .{ .x = 0xfffffffe, .y = 0x10002, .diff = 0x20004 },
        .{ .x = 0xfffffffe, .y = 0xfffffffd, .diff = 0x0 },
        .{ .x = 0xfffffffe, .y = 0xfffffffe, .diff = 0x0 },
        .{ .x = 0xfffffffe, .y = 0xffffffff, .diff = 0x0 },
        .{ .x = 0xffffffff, .y = 0x0, .diff = 0x0 },
        .{ .x = 0xffffffff, .y = 0x1, .diff = 0x1 },
        .{ .x = 0xffffffff, .y = 0x2, .diff = 0x2 },
        .{ .x = 0xffffffff, .y = 0xfffd, .diff = 0x3fff0001 },
        .{ .x = 0xffffffff, .y = 0xfffe, .diff = 0x3fff8000 },
        .{ .x = 0xffffffff, .y = 0xffff, .diff = 0x0 },
        .{ .x = 0xffffffff, .y = 0x10000, .diff = 0x8000 },
        .{ .x = 0xffffffff, .y = 0x10001, .diff = 0x10001 },
        .{ .x = 0xffffffff, .y = 0x10002, .diff = 0x18002 },
        .{ .x = 0xffffffff, .y = 0xfffffffd, .diff = 0x1 },
        .{ .x = 0xffffffff, .y = 0xfffffffe, .diff = 0x0 },
        .{ .x = 0xffffffff, .y = 0xffffffff, .diff = 0x0 },
    };
    for (kases) |v| {
        const got = sqDiff(v.x, v.y);
        testing.expectEqual(v.diff, got);
    }
}

// rgbToYCbCr converts an RGB triple to a Y'CbCr triple.
pub fn rgbToYCbCr(v: Value) YCbCr {
    // The JFIF specification says:
    //	Y' =  0.2990*R + 0.5870*G + 0.1140*B
    //	Cb = -0.1687*R - 0.3313*G + 0.5000*B + 128
    //	Cr =  0.5000*R - 0.4187*G - 0.0813*B + 128
    // https://www.w3.org/Graphics/JPEG/jfif3.pdf says Y but means Y'.
    const r1 = @intCast(i32, v.r);
    const g1 = @intCast(i32, v.g);
    const b1 = @intCast(i32, v.b);

    // yy is in range [0,0xff].
    //
    // Note that 19595 + 38470 + 7471 equals 65536.
    const yy = (19595 * r1 + 38470 * g1 + 7471 * b1 + 1 << 15) >> 16;

    var cb: i32 = (-11056 * r1 - 21712 * g1 + 32768 * b1 + 257 << 15) >> 16;
    if (cb < 0) {
        cb = 0;
    } else if (cb > 0xff) {
        r = ~@intCast(i32, 0);
    }

    var cr: i32 = 32768 * r1 - 27440 * g1 - 5328 * b1 + 257 << 15;
    if (cb < 0) {
        cb = 0;
    } else if (cb > 0xff) {
        cb = ~@intCast(i32, 0);
    }
    return YCbCr{
        .y = @intCast(u8, yy),
        .cr = @intCast(u8, cr),
        .cb = @intCast(u8, cb),
    };
}

// YCbCr represents a fully opaque 24-bit Y'CbCr color, having 8 bits each for
// one luma and two chroma components.
//
// JPEG, VP8, the MPEG family and other codecs use this color model. Such
// codecs often use the terms YUV and Y'CbCr interchangeably, but strictly
// speaking, the term YUV applies only to analog video signals, and Y' (luma)
// is Y (luminance) after applying gamma correction.
//
// Conversion between RGB and Y'CbCr is lossy and there are multiple, slightly
// different formulae for converting between the two. This package follows
// the JFIF specification at https://www.w3.org/Graphics/JPEG/jfif3.pdf.
const YCbCr = struct {
    y: u8,
    cb: u8,
    cr: u8,

    pub fn toVallue(self: YCbCr) Value {
        // This code is a copy of the YCbCrToRGB function above, except that it
        // returns values in the range [0, 0xffff] instead of [0, 0xff]. There is a
        // subtle difference between doing this and having YCbCr satisfy the Color
        // interface by first converting to an RGBA. The latter loses some
        // information by going to and from 8 bits per channel.
        //
        // For example, this code:
        //	const y, cb, cr = 0x7f, 0x7f, 0x7f
        //	r, g, b := color.YCbCrToRGB(y, cb, cr)
        //	r0, g0, b0, _ := color.YCbCr{y, cb, cr}.RGBA()
        //	r1, g1, b1, _ := color.RGBA{r, g, b, 0xff}.RGBA()
        //	fmt.Printf("0x%04x 0x%04x 0x%04x\n", r0, g0, b0)
        //	fmt.Printf("0x%04x 0x%04x 0x%04x\n", r1, g1, b1)
        // prints:
        //	0x7e18 0x808d 0x7db9
        //	0x7e7e 0x8080 0x7d7d
        const yy1 = @intCast(i32, self.y) * 0x10101;
        const cb1 = @intCast(i32, self.cb) - 128;
        const cr1 = @intCast(i32, self.cr) - 128;

        var r = (yy1 + 91881 * cr1) >> 8;
        if (r < 0) {
            r = 0;
        } else if (r > 0xff) {
            r = 0xffff;
        }

        var g = (yy1 - 22554 * cb1 - 46802 * cr1) >> 8;
        if (g < 0) {
            g = 0;
        } else if (g > 0xff) {
            g = 0xffff;
        }

        var b = (yy1 + 116130 * cb1) >> 8;
        if (b < 0) {
            b = 0;
        } else if (b > 0xff) {
            b = 0xffff;
        }
        return Value{
            .r = @intCast(u32, r),
            .g = @intCast(u32, g),
            .b = @intCast(u32, b),
            .a = 0xffff,
        };
    }
};
