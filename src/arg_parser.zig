const std = @import("std");

pub const ArgParser = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    header: []const u8 = "",
    footer: []const u8 = "",
    specs: std.StringHashMap(*const ArgSpec),
    values: std.StringHashMap(ArgValue),

    pub fn init(config: struct {
        allocator: std.mem.Allocator,
        header: []const u8 = "",
        footer: []const u8 = "",
        specs: []const ArgSpec,
    }) !ArgParser {
        var arena = std.heap.ArenaAllocator.init(config.allocator);
        var specs = std.StringHashMap(*const ArgSpec).init(arena.allocator());
        for (config.specs) |spec| {
            if (spec.names != null) {
                for (spec.names.?) |name| {
                    std.debug.print("{s} {}\n", .{ name, @TypeOf(&spec) });
                    try specs.put(name, &spec);
                }
            }
        }
        return .{
            .arena = arena,
            .allocator = config.allocator,
            .header = config.header,
            .footer = config.footer,
            .specs = specs,
            .values = std.StringHashMap(ArgValue).init(arena.allocator()),
        };
    }

    pub fn deinit(self: *ArgParser) void {
        self.arena.deinit();
    }

    pub fn parse(self: *ArgParser) !void {
        const args = try std.process.argsAlloc(self.allocator);
        defer std.process.argsFree(self.allocator, args);
        try self.parse_strings(args);
    }

    pub fn parse_strings(self: *ArgParser, args: []const []const u8) !void {
        var state: ArgState = .looking_4_arg;
        var key: []const u8 = undefined;
        for (args, 0..) |str, i| {
            if (i == 0) continue;
            std.debug.print("arg: {s} {}\n", .{ str, @TypeOf(str) });
            if (state == .looking_4_arg and self.specs.contains(str)) {
                state = .looking_4_value;
                key = str;
            } else if (state == .looking_4_value) {
                const value = ArgValue{ .String = str };
                std.debug.print("arg: {s}\n", .{str});
                std.debug.print("arg: {}\n", .{value});
                // try self.values.put(key, value);
                state = .looking_4_arg;
            }
        }
    }

    const ArgState = enum { looking_4_arg, looking_4_value };
};

pub const ArgSpec = struct {
    type: ArgType,
    names: ?[]const []const u8 = null,
    action: ArgAction = .store,
    required: bool = false,
    help: []const u8 = "",
    default: ?ArgValue = null,
};

pub const ArgValue = union(ArgType) {
    Int: i64,
    Float: f64,
    Bool: bool,
    String: []const u8,
};

pub const ArgType = enum { Int, Float, Bool, String };
pub const ArgAction = enum { store, append, store_true, store_false };
pub const ArgError = error{};
