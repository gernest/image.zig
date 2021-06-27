pub const IllegalArgument = error{
    UnfitCropRectangle,
    RowOutsideOfImage,
    InsufficientRowCopySize,
    WrongDimension,
    MismatchInputDimension,
    UnfitRegion,
    NotFound,
};
