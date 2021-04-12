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

    pub fn init(a: *std.mem.Allocator, r: Rectangle) RGBA {
        return RGBA{
            .pix = a.alloc(u8, pixelBufferLength(4, r, "RGBA")),
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

pub const RGBA64 = struct {};
pub const NRGBA = struct {};
pub const NRGBA64 = struct {};
pub const Alpha = struct {};
pub const Alpha16 = struct {};
pub const Gray = struct {};
pub const Gray16 = struct {};
pub const YCbCr = struct {};
pub const NYCbCrA = struct {};
