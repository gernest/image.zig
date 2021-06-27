const BitMatrix = @import("./bit_matrix.zig");
const Binarizer = @import("./binarizer.zig");

matrix: ?BitMatrix,
binarizer: Binarizer,

const Self = @This();
