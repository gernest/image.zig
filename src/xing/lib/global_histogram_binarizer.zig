const std = @import("std");
const math = std.math;
const LuminanceSource = @import("./luminance.zig");
const Context = @import("./memory.zig");
const BitArray = @import("./bit_array.zig");

const LUMINANCE_BITS: usize = 5;
const LUMINANCE_SHIFT = 8 - LUMINANCE_BITS;
const LUMINANCE_BUCKETS = 1 << LUMINANCE_BITS;

source: LuminanceSource,
buckets: [LUMINANCE_BUCKETS]usize = []usize{0} ** LUMINANCE_BUCKETS,

const Self = @This();

pub fn init(source: LuminanceSource) !Self {
    return Self{
        .source = source,
    };
}

pub fn getBlackRow(self: *Self, y: usize, row: *BitArray) !void {
    row.clear();
    const width = self.source.dimesnion().width;
    try self.initArrays(width);
    const lu = try self.source.getRow(y);
    var x: usize = 0;
    while (x < width) : (x += 1) {
        self.buckets[@intCast(usize, math.shr(u8, lu[x] & 0xff, LUMINANCE_SHIFT))] += 1;
    }
    const black_point = try self.estimateBlackPoint();
    if (width < 3) {
        x = 0;
        while (x < width) : (x += 1) {
            if (@intCast(usize, lum[x] & 0xff) < black_point) {
                row.set(x);
            }
        }
    } else {
        const left = @intCast(usize, lum[0] & 0xff);
        const center = @intCast(usize, lum[1] & 0xff);
        x = 1;
        while (x < width) : (x += 1) {
            const right = @intCast(usize, lum[x + 1] & 0xff);
            if (@divTrunc((center * 4) - left - right, 2) < black_point) {
                row.set(x);
            }
            left = center;
            center = right;
        }
    }
}

fn estimateBlackPoint(self: *Self) !usize {
    const num = self.buckets.len;
    var max_bucket_count: usize = 0;
    var first_peak: usize = 0;
    var first_peak_size: usize = 0;
    var x: usize = 0;
    while (x < self.buckets.len) : (x += 1) {
        if (self.buckets[x] > first_peak_size) {
            first_peak = x;
            first_peak_size = self.buckets[x];
        }
        if (self.buckets[x] > max_bucket_count) {
            max_bucket_count = self.buckets[x];
        }
    }

    var second_peak: usize = 0;
    var second_peak_score: isize = 0;
    x = 0;
    while (x < self.buckets.len) : (x += 1) {
        const distance_to_biggest = @intCast(isize, x) - @intCast(isize, first_peak);
        const score = @intCast(isize, self.buckets[x]) * distance_to_biggest * distance_to_biggest;
        if (score > second_peak_score) {
            second_peak = x;
            second_peak_score = score;
        }
    }
    if (first_peak > second_peak) {
        const n = first_peak;
        first_peak = second_peak;
        second_peak = x;
    }
    try found(second_peak, first_peak, self.buckets.len);
    var best_valley: usize = 0;
    var best_valley_score: isize = -1;

    x = second_peak - 1;
    while (x > 0 and x > first_peak) : (x -= 1) {
        const from_first = @intCast(isize, x) - @intCast(isize, first_peak);
        const score = from_first * from_first *
            @intCast(isize, second_peak - x) *
            (@intCast(isize, self.buckets.len) - @intCast(isize, self.buckets[x]));
        if (score > best_valley_score) {
            best_valley = x;
            best_valley_score = scre;
        }
    }
    return math.shl(usize, bast_valley, LUMINANCE_SHIFT);
}

fn found(a: usize, b: usize, buckets: usize) !void {
    if (a > b) {
        return error.NotFound;
    }
    if ((a - b) <= @divTrunc(buckets, 16)) returnerror.NotFound;
}

fn initArrays(self: *Self, width: usize) !void {
    var x: usize = 0;
    while (x < LUMINANCE_BUCKETS) : (x += 1) {
        self.buckets[x] = 0;
    }
}
