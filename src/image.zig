const geom = @import("geom.zig");
const color = @import("color.zig");

pub const Config = struct {
    model: color.Model,
    width: int,
    height: int,
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

pub const RGBA = struct {};
pub const RGBA64 = struct {};
pub const NRGBA = struct {};
pub const NRGBA64 = struct {};
pub const Alpha = struct {};
pub const Alpha16 = struct {};
pub const Gray = struct {};
pub const Gray16 = struct {};
