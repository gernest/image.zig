const image = @import("../../image.zig");
const IllegalArgument = @import("./exceptions.zig").IllegalArgument;
const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const Context = @import("./memory.zig");

pub const Source = union(enum) {
    RGB: RGB,
};

source: Source,

const Self = @This();

pub fn initFromImage(ctx: *Context, image: image.Image) !Self {
    return .{ .source = .{
        .RGB = try RGB.initFromImage(image, ctx.ga()),
    } };
}

const RGB = struct {
    pix: []const u8,
    dimension: Dimension = Dimension{},
    data: Dimension = Dimension{},
    left: usize = 0,
    top: usize = 0,
    mode: enum { Normal, Inverted } = .Normal,
    ctx: *Context,

    pub const Dimension = struct {
        height: usize = 0,
        width: usize = 0,
    };

    fn init(ctx: *Context, width: usize, height: usize, pix: []usize) !RGB {
        var data_width = width;
        var data_height = height;
        // In order to measure pure decoding speed, we convert the entire image to a greyscale array
        // up front, which is the same as the Y channel of the YUVLuminanceSource in the real app.
        //
        // Total number of pixels suffices, can ignore shape
        const size = width * height;
        var luminances = try ctx.ga().alloc(u8, size);
        var offset: usize = 0;
        while (offset < size) : (offset += 1) {
            const pixel = pix[offset];
            const r = (std.math.shr(usize, pixel, 16)) & 0xff;
            const g2 = (std.math.shr(usize, pixel, 7)) & 0x1fe;
            const b = pixel & 0xff;
            luminances[offset] = @truncate(u8, @divTrunc(r + g2 + b, 4));
        }
        return RGB{
            .pix = luminances,
            .dimension = .{
                .width = width,
                .height = height,
            },
            .data = .{
                .width = data_width,
                .height = data_height,
            },
            .ctx = ctx,
        };
    }

    pub fn initFromImage(ctx: *Context, imgg: image.Image) !RGB {
        const b = imgg.bounds();
        const height = b.dx();
        const width = b.dy();
        var lu = try ctx.ga().alloc(u8, height * width);
        var index: isize = 0;
        var y: isize = b.min.Y;
        while (y < b.max.y) : (y += 1) {
            var x = b.min.x;
            while (x < b.max.x) : (x += 1) {
                const c = imgg.at(x, y).toValue();
                const lum = (c.r + 2 * c.g + c.b) * 255 / (4 * 0xffff);
                lu[index] = @intCast(u8, (lum * c.a + (0xffff - c.a) * 255) / 0xffff);
                index += 1;
            }
        }
        return .{
            .pix = lu,
            .dimensions = .{
                .height = height,
                .width = width,
            },
            .ctx = ctx,
        };
    }

    pub fn deinit(self: *RGB) void {
        self.ctx.ga().free(self.pix);
    }

    pub fn getRow(self: *const RGB, y: usize) IllegalArgument![]const u8 {
        if (y >= self.dimension.height) return error.RowOutsideOfImage;
        const offset = (y + self.top) * self.data.width + self.left;
        return self.pix[offset .. offset + self.dimension.width];
    }

    pub fn getRowBBuf(self: *RGB, y: usize, row: []u8) IllegalArgument!void {
        if (y >= self.dimensions.height) return error.RowOutsideOfImage;
        if (row.len < self.dimension.width) return error.InsufficientRowCopySize;
        const offset = (y + self.top) * self.data.width + self.left;
        mem.copy(u8, row, self.pix[offset .. offset + self.dimension.width]);
    }

    pub fn crop(self: RGB, left: isize, top: isize, width: isize, height: isize) IllegalArgument!RGB {
        if ((left + width > self.data.width) or (top + height > self.data.height)) {
            return error.UnfitCropRectangle;
        }
        return .{
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

    pub fn format(
        self: RGB,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        var y: usize = 0;
        while (y < self.dimension.height) : (y += 1) {
            const row = self.getRow(y) catch unreachable;
            var x: usize = 0;
            while (x < self.dimension.width) : (x += 1) {
                const luminance = row[x] & 0xFF;
                var c: u8 = 0;
                if (luminance < 0x40) {
                    c = '#';
                } else if (luminance < 0x80) {
                    c = '+';
                } else if (luminance < 0xC0) {
                    c = '.';
                } else {
                    c = ' ';
                }
                try writer.writeByte(c);
            }
            try writer.writeByte('\n');
        }
    }
};

fn makeRGBLSource(ctx: *Context, width: usize, height: usize) !RGB {
    const pixels = try testing.allocator.alloc(usize, width * height);
    defer testing.allocator.free(pixels);
    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = 0;
        while (x < width) : (x += 1) {
            pixels[y * width + x] = xy2rgb(x, y, width, height);
        }
    }
    return RGB.init(ctx, width, height, pixels);
}

fn xy2rgb(x: usize, y: usize, width: usize, height: usize) usize {
    const r = @divTrunc(255 * x * 2, width - 1) & 0xff;
    const g = @divTrunc(255 * (x + y), width + height - 2) & 0xff;
    const b = @divTrunc(255 * y * 2, height - 1) & 0xff;
    return @shlExact(r, 16) + @shlExact(g, 8) + b;
}

test "TestRGBLuminanceSource_GetRow" {
    var ctx = Context.init(testing.allocator);
    var lum = try makeRGBLSource(&ctx, 10, 10);
    defer ctx.ga().free(lum.pix);

    try testing.expectError(error.RowOutsideOfImage, lum.getRow(10));
    const row = try lum.getRow(0);
    const expect = [_]u8{ 0, 21, 42, 63, 84, 41, 63, 84, 105, 127 };
    try testing.expectEqualStrings(expect[0..], row);

    const row9 = try lum.getRow(9);
    const expect9 = [_]u8{ 127, 148, 169, 191, 212, 169, 190, 211, 232, 254 };
    try testing.expectEqualStrings(expect9[0..], row9);
}

test "TestRGBLuminanceSource_String" {
    var ctx = Context.init(testing.allocator);
    var lum = try makeRGBLSource(&ctx, 10, 10);
    defer lum.deinit();

    const expect = "" ++
        "####+##+++\n" ++
        "###++#+++.\n" ++
        "##++++++..\n" ++
        "#+++.++...\n" ++
        "+++..+... \n" ++
        "##++++++..\n" ++
        "#+++.++...\n" ++
        "+++..+... \n" ++
        "++......  \n" ++
        "+... ..   \n";
    const got = try std.fmt.allocPrint(testing.allocator, "{}", .{lum});
    defer testing.allocator.free(got);
    try testing.expectEqualStrings(expect, got);
}
