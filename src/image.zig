const geom = @import("geom.zig");
const color = @import("color.zig");
const std = @import("std");
const testing = std.testing;
const print = std.debug.print;

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
    nrgba64: NRGBA64,
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
        };
    }

    // used for testing. This returns underlying pix slice for easily freeing up
    // test images
    fn pix(self: Image) []u8 {
        return switch (self) {
            .rgba => |i| i.pix,
            .rgba64 => |i| i.pix,
            .nrgba => |i| i.pix,
            .nrgba64 => |i| i.pix,
            .alpha => |i| i.pix,
            .alpha16 => |i| i.pix,
            .gray => |i| i.pix,
            .gray16 => |i| i.pix,
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
            .pix = try createPix(a, 4, r, "RGBA"),
            .stride = 4 * r.dx(),
            .rect = r,
        };
    }

    pub fn at(self: RGBA, x: isize, y: isize) ?Color {
        const point = Point{ .x = x, .y = y };
        if (!point.in(self.rect)) return null;
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

    pub fn pixOffset(self: RGBA, x: isize, y: isize) usize {
        const v = (y - self.rect.min.y) * self.stride + (x - self.rect.min.x) * 4;
        return @intCast(usize, v);
    }

    pub fn set(self: RGBA, x: isize, y: isize, c: Color) void {
        const point = Point{ .x = x, .y = y };
        if (point.in(self.rect)) {
            const i = self.pixOffset(x, y);
            const c1 = color.RGBAModel.convert(c).toValue();
            const s = self.pix[i .. i + 4];
            s[0] = @truncate(u8, c1.r);
            s[1] = @truncate(u8, c1.g);
            s[2] = @truncate(u8, c1.b);
            s[3] = @truncate(u8, c1.a);
        }
    }

    pub fn subImage(self: RGBA, r: Rectangle) ?Image {
        const n = r.intersect(self.rect);
        if (n.empty()) return null;
        const i = self.pixOffset(r.min.x, r.min.y);
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

    pub fn at(self: RGBA64, x: isize, y: isize) ?Color {
        const point = Point{ .x = x, .y = y };
        if (!point.in(self.rect)) return null;
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
            const c1 = color.RGBA64Model.convert(c).toValue();
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

    pub fn subImage(self: RGBA64, r: Rectangle) ?Image {
        const n = r.intersect(self.rect);
        if (n.empty()) return null;
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

    pub fn at(self: NRGBA, x: isize, y: isize) ?Color {
        const point = Point{ .x = x, .y = y };
        if (!point.in(self.rect)) return null;
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
            const c1 = color.NRGBAModel.convert(c).toValue();
            var s = self.pix[i .. i + 4];
            s[0] = @truncate(u8, c1.r);
            s[1] = @truncate(u8, c1.g);
            s[2] = @truncate(u8, c1.b);
            s[3] = @truncate(u8, c1.a);
        }
    }

    pub fn subImage(self: NRGBA, r: Rectangle) ?Image {
        const n = r.intersect(self.rect);
        if (n.empty()) return null;
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

    pub fn at(self: NRGBA64, x: isize, y: isize) ?Color {
        const point = Point{ .x = x, .y = y };
        if (!point.in(self.rect)) return null;
        const i = self.pixOffset(x, y);
        const s = self.pix[i .. i + 8];
        return color.Color{
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
            const c1 = color.NRGBA64Model.convert(c).toValue();
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

    pub fn subImage(self: NRGBA64, r: Rectangle) ?Image {
        const n = r.intersect(self.rect);
        if (n.empty()) return null;
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

    pub fn at(self: Alpha, x: isize, y: isize) ?Color {
        const point = Point{ .x = x, .y = y };
        if (!point.in(self.rect)) return null;
        const i = self.pixOffset(x, y);
        return color.Color{
            .alpha = color.Alpha{
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
            self.pix[i] = color.AlphaModel.convert(c).alpha.a;
        }
    }

    pub fn subImage(self: Alpha, r: Rectangle) ?Image {
        const n = r.intersect(self.rect);
        if (n.empty()) return null;
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

    pub fn at(self: Alpha16, x: isize, y: isize) ?Color {
        const point = Point{ .x = x, .y = y };
        if (!point.in(self.rect)) return null;
        const i = self.pixOffset(x, y);
        return color.Color{
            .alpha16 = color.Alpha16{
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
            const c1 = color.Alpha16Model.convert(c).alpha16;
            self.pix[i + 0] = @truncate(u8, c1.a >> 8);
            self.pix[i + 1] = @truncate(u8, c1.a);
        }
    }

    pub fn subImage(self: Alpha16, r: Rectangle) ?Image {
        const n = r.intersect(self.rect);
        if (n.empty()) return null;
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

    pub fn at(self: Gray, x: isize, y: isize) ?Color {
        const point = Point{ .x = x, .y = y };
        if (!point.in(self.rect)) return null;
        const i = self.pixOffset(x, y);
        return color.Color{
            .gray = color.Gray{
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
            self.pix[i] = color.GrayModel.convert(c).gray.y;
        }
    }

    pub fn subImage(self: Gray, r: Rectangle) ?Image {
        const n = r.intersect(self.rect);
        if (n.empty()) return null;
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
    pub fn at(self: Gray16, x: isize, y: isize) ?Color {
        const point = Point{ .x = x, .y = y };
        if (!point.in(self.rect)) return null;
        const i = self.pixOffset(x, y);
        return color.Color{
            .gray16 = color.Gray16{
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
            const c1 = color.Gray16Model.convert(c).gray16;
            self.pix[i + 0] = @truncate(u8, c1.y >> 8);
            self.pix[i + 1] = @truncate(u8, c1.y);
        }
    }

    pub fn subImage(self: Gray16, r: Rectangle) ?Image {
        const n = r.intersect(self.rect);
        if (n.empty()) return null;
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

pub const CMYK = struct {};

pub const YCbCr = struct {
    pix: []u8,
    stride: isize,
    rect: Rectangle,
};

pub const NYCbCrA = struct {
    pix: []u8,
    stride: isize,
    rect: Rectangle,
};

fn cmp(cm: color.Model, c0: Color, c1: Color) bool {
    // std.debug.print("\nc0={any} c1={any}\n", .{ c0, c1 });
    const v0 = cm.convert(c0).toValue();
    const v1 = cm.convert(c1).toValue();
    // std.debug.print("\nv0={any} v1={any}\n", .{ v0, v1 });
    return v0.eq(v1);
}

test "Image" {
    const AllocationError = error{
        OutOfMemory,
    };
    const initImage = struct {
        init: fn () AllocationError!Image,

        fn rgba() !Image {
            return Image{
                .rgba = try RGBA.init(testing.allocator, Rectangle.init(0, 0, 10, 10)),
            };
        }

        fn rgba64() !Image {
            return Image{
                .rgba64 = try RGBA64.init(testing.allocator, Rectangle.init(0, 0, 10, 10)),
            };
        }
        fn nrgba() !Image {
            return Image{
                .nrgba = try NRGBA.init(testing.allocator, Rectangle.init(0, 0, 10, 10)),
            };
        }
        fn nrgba64() !Image {
            return Image{
                .nrgba64 = try NRGBA64.init(testing.allocator, Rectangle.init(0, 0, 10, 10)),
            };
        }

        fn alpha() !Image {
            return Image{
                .alpha = try Alpha.init(testing.allocator, Rectangle.init(0, 0, 10, 10)),
            };
        }

        fn alpha16() !Image {
            return Image{
                .alpha16 = try Alpha16.init(testing.allocator, Rectangle.init(0, 0, 10, 10)),
            };
        }
        fn gray() !Image {
            return Image{
                .gray = try Gray.init(testing.allocator, Rectangle.init(0, 0, 10, 10)),
            };
        }
        fn gray16() !Image {
            return Image{
                .gray16 = try Gray16.init(testing.allocator, Rectangle.init(0, 0, 10, 10)),
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
        testing.expect(cmp(m.colorModel(), color.Transparent, m.at(6, 3).?));

        m.set(6, 3, color.Opaque);
        testing.expect(cmp(m.colorModel(), color.Opaque, m.at(6, 3).?));

        testing.expect(m.subImage(Rectangle.rect(6, 3, 7, 4)).?.@"opaque"());

        const m2 = m.subImage(Rectangle.rect(3, 2, 9, 8)).?;
        testing.expect(Rectangle.rect(3, 2, 9, 8).eq(m2.bounds()));

        testing.expect(cmp(m2.colorModel(), color.Opaque, m2.at(6, 3).?));
        testing.expect(cmp(m2.colorModel(), color.Transparent, m2.at(3, 3).?));
        m2.set(3, 3, color.Opaque);
        testing.expect(cmp(m2.colorModel(), color.Opaque, m2.at(3, 3).?));

        _ = m2.subImage(Rectangle.rect(0, 0, 0, 0));
        _ = m2.subImage(Rectangle.rect(10, 0, 10, 0));
        _ = m2.subImage(Rectangle.rect(0, 10, 0, 10));
        _ = m2.subImage(Rectangle.rect(10, 10, 10, 10));
        testing.allocator.free(m.pix());
    }
}
