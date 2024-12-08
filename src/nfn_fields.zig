const std = @import("std");

pub const BoxField = struct {};

pub const HighlighterField = struct {};

pub const LengthField = struct {};

pub const MarkIndexField = struct {};

pub const NoopField = struct {};

pub const PointField = struct {};

pub const PolygonField = struct {};

pub const SameField = struct {
    name: []u8,
    not: []u8,
    value: []u8,
};

pub const SelectField = struct {};

pub const TextField = struct {};
