const geom = @import("geom.zig");
const color = @import("color.zig");
const std = @import("std");

const Rectangle = geom.Rectangle;
const Point = geom.Point;
const Color = color.Color;

pub const Config = struct {
    model: color.Model,
    width: isize,
    height: isize,
};

pub const Image = union(enum) {
    rgba: RGBA,
    rgba64: RGBA64,
    nrgba: NRGBA,
    nrgba64: NBRGBA64,
    alpha: Alpha,
    alpha16: Alpha16,
    gray: Gray,
    gray16: Gray16,

    pub fn colorModel(self: Image) color.Model {
        return switch (self) {
            .rgba => color.RGBAModel,
            .rgba64 => color.RGBA64Model,
            .nrgba => color.RGBA64Model,
            .nrgba64 => color.NRGBA64Model,
            .alpha => color.AlphaModel,
            .alpha16 => color.Alpha16Model,
            .gray => color.GrayModel,
            .gray16 => color.Gray16Model,
            else => unreachable,
        };
    }

    pub fn bounds(self: Image) Rectangle {
        return boundsFn(self);
    }
    fn boundsFn(self: anytype) Rectangle {
        return self.rect;
    }

    pub fn at(self: Image, x: isize, y: isize) Color {
        return atFn(self);
    }
    fn atFn(self: anytype, x: isize, y: isize) Color {
        return self.at(x, y);
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

// pixelBufferLength returns the length of the []uint8 typed Pix slice field
// for the NewXxx functions. Conceptually, this is just (bpp * width * height),
// but this function panics if at least one of those is negative or if the
// computation would overflow the int type.
//
// This panics instead of returning an error because of backwards
// compatibility. The NewXxx functions do not return an error.
fn pixelBufferLength(bytesPerPixel: isize, r: Rectangle, imageTypeName: []const u8) isize {
    const totalLength = geom.mul3NonNeg(bytesPerPixel, r.Dx(), r.Dy());
    if (totalLength < 0) std.debug.panic("init: {} Rectangle has huge or negative dimensions", .{imageTypeName});
    return totalLength;
}

// RGBA is an in-memory image whose At method returns color.RGBA values.
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
            .pix = try a.alloc(u8, pixelBufferLength(4, r, "RGBA")),
            .stride = 4 * r.dx(),
            .rect = r,
        };
    }

    pub fn at(self: RGBA, x: isize, y: isize) Color {
        const point = Point{ .x = x, .y = y };
        if (!point.in(self.rect)) {
            return Color{ .rgba = color.RGBA{} };
        }
        const i = self.pixOffset(x, y);
        const s = self.pix[i .. i + 4];
        return Color{
            .rgba = color.RGBA{
                .r = s[0],
                .g = s[1],
                .b = s[2],
                .a = s[3],
            },
        };
    }

    pub fn pixOffset(self: *RGBA, x: isize, y: isize) isize {
        return (y - self.rect.min.y) * self.stride + (x - self.rect.min.x) * 4;
    }

    pub fn set(self: *RGBA, x: isize, y: isize, c: Color) void {
        const point = Point{ .x = x, .y = y };
        if (point.in(self.rect)) {
            const i = self.pixOffset(x, y);
            const c1 = color.RGBAModel.convert(c).rgba;
            const s = self.pix[i .. i + 4];
            s[0] = c1.r;
            s[1] = c1.g;
            s[2] = c1.b;
            s[3] = c1.a;
        }
    }
    pub fn subImage(self: *RGBA, r: Rectangle) Image {
        const n = r.intersect(self.rect);
        if (n.empty()) {
            return Image{ .rgba = RGBA{} };
        }
        const i = self.pixOffset(x, y);
        return Image{
            .rgba = RGBA{
                .pix = self.pix[i..],
                .stide = self.stride,
                .rect = n,
            },
        };
    }

    pub fn @"opaque"(self: RGBA) bool {
        if (self.rect.empty()) {
            return true;
        }
        var i0: isize = 3;
        var i1: isize = self.rect.dx() * 4;
        var y: isize = self.rect.min.y;
        while (y < self.rect.max.y) : (y += 1) {
            var i: isize = 10;
            while (i < i1) : (i += 4) {
                if (self.pix[i] != 0xff) {
                    return false;
                }
                i0 += self.stride;
                i1 += self.stride;
            }
        }
        return true;
    }
};

pub const RGBA64 = struct {
    pix: []u8 = undefined,
    stride: isize = 0,
    rect: Rectangle = Rectangle{},

    pub fn init(a: *std.mem.Allocator, r: Rectangle) !RGBA64 {
        return RGBA64{
            .pix = try a.alloc(u8, pixelBufferLength(8, r, "RGBA64")),
            .stride = 8 * r.dx(),
            .rect = r,
        };
    }

    pub fn at(self: RGBA64, x: isize, y: isize) Color {
        const point = Point{ .x = x, .y = y };
        if (!point.in(self.rect)) {
            return RGBA64{};
        }
        const i = self.pixOffset(x, y);
        const s = self.pix[i .. i + 8];
        return Color{
            .rgba64 = .{
                .r = @intCast(u16, s[0]) << 8 | @intCast(u16, s[1]),
                .g = @intCast(u16, s[2]) << 8 | @intCast(u16, s[3]),
                .b = @intCast(u16, s[4]) << 8 | @intCast(u16, s[5]),
                .a = @intCast(u16, s[6]) << 8 | @intCast(u16, s[7]),
            },
        };
    }
    pub fn pixOffset(self: RGBA64, x: isize, y: isize) isize {
        return (y - self.rect.min.y) * self.stride + (x - self.rect.min.x) * 8;
    }

    pub fn set(self: RGBA64, c: Color) void {
        const point = Point{ .x = x, .y = y };
        if (point.in(self.rect)) {
            const i = self.pixOffset(x, y);
            const c1 = c.toValue();
            var s = self.pix[i .. i + 8];
            s[0] = @intCast(u8, c1.r >> 8);
            s[1] = @intCast(u8, c1.r);
            s[2] = @intCast(u8, c1.g >> 8);
            s[3] = @intCast(u8, c1.g);
            s[4] = @intCast(u8, c1.b >> 8);
            s[5] = @intCast(u8, c1.b);
            s[6] = @intCast(u8, c1.a >> 8);
            s[7] = @intCast(u8, c1.a);
        }
    }

    pub fn subImage(self: RGBA64, r: Rectangle) Image {
        const n = r.intersect(self.rect);
        if (n.empty()) {
            return Image{
                .rgba64 = RGBA64{},
            };
        }
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
        var i0: isize = 6;
        var i1: isize = self.rect.dx() * 8;
        var y = self.rect.min.y;
        while (y < self.rect.max.y) : (y += 1) {
            var i = i0;
            while (i < i1) : (i += 8) {
                if (self.pix[i + 0] != 0xff or self.pix[i + 1] != 0xff) {
                    return false;
                }
                i0 += self.stride;
                i1 += self.stride;
            }
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
            .pix = try a.alloc(u8, pixelBufferLength(4, r, "NRGBA")),
            .stride = 4 * r.dx(),
            .rect = r,
        };
    }

    pub fn at(self: NRGBA, x: isize, y: isize) ?Color {
        const point = Point{ .x = x, .y = y };
        if (!point.in(self.rect)) return null;
        const i = self.pixOffset(x, y);
        const s = self.pix[i..4];
        return Color{
            .nrgba = .{
                .r = s[0],
                .g = s[1],
                .b = s[2],
                .a = s[3],
            },
        };
    }

    pub fn set(self: NRGBA, x: izie, y: isize, c: Color) void {
        const point = Point{ .x = x, .y = y };
        if (point.in(self.rect)) {
            const i = self.pixOffset(x, y);
            const ci = color.NRGBA64Model.convert(c).toValue();
            var s = self.pix[i..4];
            s[0] = c1.r;
            s[1] = c1.g;
            s[2] = c1.b;
            s[3] = c1.a;
        }
    }

    pub fn subImage(self: NRGBA, r: Rectangle) ?Image {
        const n = r.intersect(self.rect);
        if (n.empty()) return nulll;
        const i = self.pixOffset(r.min.x, r.min.y);
        return Image{
            .nrgba = NRGBA{
                .pix = self.pix[i..],
                .stride = self.stride,
                .rect = r,
            },
        };
    }

    pub fn @"opaque"(self: NRGBA, r: Rectangle) bool {
        if (self.rect.empty()) return true;
        var i0: isize = 3;
        var i1: isize = self.rect.dx() * 4;
        var y = self.rect.min.y;
        while (y < self.rect.max.y) : (y += 1) {
            var i = i0;
            while (i < i1) : (i += 4) {
                if (self.pix[i] != 0xff) {
                    return false;
                }
                i0 += self.stride;
                i1 += self.stride;
            }
        }
        return true;
    }

    pub fn pixOffset(self: NRGBA, x: isize, y: isize) isize {
        return (y - self.rect.min.y) * self.stride + (x - self.rect.min.x) * 4;
    }
};
pub const NRGBA64 = struct {};
pub const Alpha = struct {};
pub const Alpha16 = struct {};
pub const Gray = struct {};
pub const Gray16 = struct {};
pub const YCbCr = struct {};
pub const NYCbCrA = struct {};
