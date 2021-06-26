pub const IllegalArgument = error{
    /// Crop rectangle does not fit within image data
    UnfitCropRectangle,
    RowOutsideOfImage,
    InsufficientRowCopySize,
};
