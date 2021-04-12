const color = @import("color.zig");
const testing = @import("std").testing;
const debug = @import("std").debug;

/// A Point is an X, Y coordinate pair. The axes increase right and down.
pub const Point = struct {
    x: isize = 0,
    y: isize = 0,

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
        return r.min.x >= r.max.x or r.min.y >= r.max.y;
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
            testing.expectEqual(got, want);
        }
    }
    for (rectangles) |r| {
        for (rectangles) |s| {
            const a = r.intersect(s);
            testing.expect(check.in(a, r));
            testing.expect(check.in(a, s));
            const is_zero = a.eq(Rectangle.zero());
            const overlaps = r.overlaps(s);
            testing.expect(is_zero != overlaps);
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
                testing.expect(!(check.in(b, r) and check.in(b, s)));
            }
        }
    }

    for (rectangles) |r| {
        for (rectangles) |s| {
            const a = r.runion(s);
            testing.expect(check.in(r, a));
            testing.expect(check.in(s, a));
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
                testing.expect(!(check.in(r, b) and check.in(s, b)));
            }
        }
    }
}

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
        testing.expectEqual(r, v.want);
    }

    // symetric
    for (kases) |v, i| {
        const r = mul64(v.y, v.x);
        testing.expectEqual(r, v.want);
    }
}

// add2NonNeg returns (x + y), unless at least one argument is negative or if
// the computation overflows the int type, in which case it returns -1.
pub fn add2NonNeg(x: isize, y: isize) isize {
    if ((x < 0) or (y < 0)) return -1;
    const a = x + y;
    if (a < 0) return -1;
    return a;
}
