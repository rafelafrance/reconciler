const std = @import("std");

pub const SameField = struct {
    name: []u8,
    not: []u8,
    value: []u8,
};

pub const FieldFlag = enum { NoFlag };
