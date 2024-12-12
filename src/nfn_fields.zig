const std = @import("std");

pub const Table = struct {
    allocator: std.mem.Allocator,
    rows: std.ArrayList(*Row),
    types: std.StringHashMap(*AnyField),

    pub fn init(config: struct { allocator: std.mem.Allocator }) !Row {
        return .{
            .allocator = config.allocator,
            .rows = std.ArrayList(*Row).init(config.allocator),
            .types = std.StringHashMap(*AnyField).init(config.allocator),
        };
    }
};

pub const Row = struct {
    allocator: std.mem.Allocator,
    fields: std.StringHashMap(*AnyField),
    suffixes: std.StringHashMap(u16),

    pub fn init(config: struct { allocator: std.mem.Allocator }) !Row {
        return .{
            .allocator = config.allocator,
            .fields = std.StringHashMap(*AnyField).init(config.allocator),
            .suffixes = std.StringHashMap(u16).init(config.allocator),
        };
    }

    // pub fn add(self: *Row, field: AnyField) !void {}
};

pub const AnyFieldEnum = enum {
    box_field,
    highlighter_field,
    length_field,
    mark_index_field,
    noop_field,
    point_field,
    polygon_field,
    same_field,
    select_field,
    text_field,
};

pub const AnyField = union(AnyFieldEnum) {
    box_field: BoxField,
    highlighter_field: HighlighterField,
    length_field: LengthField,
    mark_index_field: MarkIndexField,
    noop_field: NoopField,
    point_field: PointField,
    polygon_field: PolygonField,
    same_field: SameField,
    select_field: SelectField,
    text_field: TextField,
};

// pub const BaseField = struct {
//     field_set: ?[]u8 = undefined,
// };

pub const BoxField = struct {
    name: []const u8,
    task_id: []const u8,
    flag: Flag = Flag.no_flag,
    suffix: u16 = 0,
    note: ?[]u8 = undefined,
    field_set: ?[]u8 = undefined,

    left: f32,
    right: f32,
    top: f32,
    bottom: f32,
};

pub const HighlighterField = struct {
    name: []const u8,
    task_id: []const u8,
    flag: Flag = Flag.no_flag,
    suffix: u16 = 0,
    note: ?[]u8 = undefined,
    field_set: ?[]u8 = undefined,
};

pub const LengthField = struct {
    name: []const u8,
    task_id: []const u8,
    flag: Flag = Flag.no_flag,
    suffix: u16 = 0,
    note: ?[]u8 = undefined,
    field_set: ?[]u8 = undefined,
};

pub const MarkIndexField = struct {
    name: []const u8,
    task_id: []const u8,
    flag: Flag = Flag.no_flag,
    suffix: u16 = 0,
    note: ?[]u8 = undefined,
    field_set: ?[]u8 = undefined,
};

pub const NoopField = struct {
    name: []const u8,
    task_id: []const u8,
    flag: Flag = Flag.no_flag,
    suffix: u16 = 0,
    note: ?[]u8 = undefined,
    field_set: ?[]u8 = undefined,
};

pub const PointField = struct {
    name: []const u8,
    task_id: []const u8,
    flag: Flag = Flag.no_flag,
    suffix: u16 = 0,
    note: ?[]u8 = undefined,
    field_set: ?[]u8 = undefined,
};

pub const PolygonField = struct {
    name: []const u8,
    task_id: []const u8,
    flag: Flag = Flag.no_flag,
    suffix: u16 = 0,
    note: ?[]u8 = undefined,
    field_set: ?[]u8 = undefined,
};

pub const SameField = struct {
    name: []const u8,
    task_id: []const u8,
    flag: Flag = Flag.no_flag,
    suffix: u16 = 0,
    note: ?[]u8 = undefined,
    field_set: ?[]u8 = undefined,
    value: []u8,
};

pub const SelectField = struct {
    name: []const u8,
    task_id: []const u8,
    flag: Flag = Flag.no_flag,
    suffix: u16 = 0,
    note: ?[]u8 = undefined,
    field_set: ?[]u8 = undefined,
    value: []const u8,

    pub fn init(name: []const u8, task_id: []const u8, value: []const u8) !TextField {
        return .{ .name = name, .task_id = task_id, .value = value };
    }
};

pub const TextField = struct {
    name: []const u8,
    task_id: []const u8,
    flag: Flag = Flag.no_flag,
    suffix: u16 = 0,
    note: ?[]u8 = undefined,
    field_set: ?[]u8 = undefined,
    value: []const u8,

    pub fn init(name: []const u8, task_id: []const u8, value: []const u8) !TextField {
        return .{ .name = name, .task_id = task_id, .value = value };
    }
};

pub const Flag = enum {
    no_flag,
    ok,
    unamimous,
    majority,
    fuzzy,
    all_blank,
    only_one,
    no_match,
    error_,
};
