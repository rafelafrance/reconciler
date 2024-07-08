const std = @import("std");

const print = std.debug.print;

pub const ArgParser = struct {
    allocator: std.mem.Allocator,
    header: []const u8,
    footer: []const u8,
    specs: std.ArrayList(*ArgSpec),
    names: std.StringHashMap(*ArgSpec),
    values: std.StringHashMap(ArgValue),

    pub fn init(config: struct {
        allocator: std.mem.Allocator,
        header: []const u8 = "",
        footer: []const u8 = "",
    }) !ArgParser {
        const parser = ArgParser{
            .allocator = config.allocator,
            .header = config.header,
            .footer = config.footer,
            .specs = std.ArrayList(*ArgSpec).init(config.allocator),
            .names = std.StringHashMap(*ArgSpec).init(config.allocator),
            .values = std.StringHashMap(ArgValue).init(config.allocator),
        };
        return parser;
    }

    pub fn add(self: *ArgParser, config: struct {
        type: ArgType,
        named: bool = true,
        name: []const u8 = "",
        action: ArgAction = .store,
        required: bool = false,
        help: []const u8 = "",
        default: ?ArgValue = null,
    }) !void {
        const ptr = try self.allocator.create(ArgSpec);
        errdefer self.allocator.destroy(ptr);

        ptr.* = ArgSpec{
            .type = config.type,
            .named = config.named,
            .name = config.name,
            .action = config.action,
            .required = config.required,
            .default = config.default,
            .help = config.help,
        };

        try self.specs.append(ptr);

        if (ptr.named) {
            try self.names.put(ptr.name, ptr);
        }
    }

    pub fn deinit(self: *ArgParser) void {
        self.names.deinit();
        self.values.deinit();

        for (self.specs.items) |spec| {
            self.allocator.destroy(spec);
        }
        self.specs.deinit();
    }

    pub fn parse(self: *ArgParser) !void {
        const args = try std.process.argsAlloc(self.allocator);
        defer std.process.argsFree(self.allocator, args);
        try self.parse_strings(args);
        var iter = self.values.iterator();
        while (iter.next()) |item| {
            print("key: {s} value: {}\n", .{ item.key_ptr.*, item.value_ptr.* });
        }
    }

    pub fn parse_strings(self: *ArgParser, args: []const []const u8) !void {
        var state: ArgState = .arg_next;
        var spec: *const ArgSpec = undefined;
        for (args, 0..) |str, i| {
            if (i == 0) continue;
            if (state == .arg_next and self.names.contains(str)) {
                spec = self.names.get(str).?;
                print("arg: {s} {}\n", .{ str, @TypeOf(str) });
                state = .value_next;
            } else if (state == .value_next) {
                const value = ArgValue{ .String = str };
                print("arg value: {s} {}\n", .{ str, value });
                // try self.values.put(key, value);
                state = .arg_next;
            }
        }
    }

    const ArgState = enum { arg_next, value_next };
};

pub const ArgSpec = struct {
    type: ArgType,
    named: bool,
    name: []const u8,
    action: ArgAction,
    required: bool,
    help: []const u8,
    default: ?ArgValue,
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
