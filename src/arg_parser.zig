const std = @import("std");

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
        return .{
            .allocator = config.allocator,
            .header = config.header,
            .footer = config.footer,
            .specs = std.ArrayList(*ArgSpec).init(config.allocator),
            .names = std.StringHashMap(*ArgSpec).init(config.allocator),
            .values = std.StringHashMap(ArgValue).init(config.allocator),
        };
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

        if (ptr.named) try self.names.put(ptr.name, ptr);
    }

    pub fn deinit(self: *ArgParser) void {
        self.names.deinit();
        self.values.deinit();

        for (self.specs.items) |spec| self.allocator.destroy(spec);
        self.specs.deinit();
    }

    pub fn parse(self: *ArgParser) !void {
        const args = try std.process.argsAlloc(self.allocator);
        defer std.process.argsFree(self.allocator, args);
        try self.parseStrings(args);
    }

    pub fn parseStrings(self: *ArgParser, args: []const []const u8) !void {
        var state: ArgState = .arg_expected;
        var spec: *const ArgSpec = undefined;
        var name: []const u8 = undefined;
        for (args, 0..) |str, i| {
            if (i == 0) continue;
            if (state == .arg_expected and self.names.contains(str)) {
                spec = self.names.get(str).?;
                name = str;
                if (spec.type == .Bool) {
                    try self.values.put(name, ArgValue{ .bool = switch (spec.action) {
                        .store_true => true,
                        .store_false => false,
                        else => {
                            std.log.err("Error {!}", .{ArgError.InvalidBool});
                            return ArgError.InvalidBool;
                        },
                    } });
                    state = .arg_expected;
                } else {
                    state = .value_expected;
                }
            } else if (state == .value_expected) {
                const value = switch (spec.type) {
                    ArgType.Int => ArgValue{
                        .int = std.fmt.parseInt(i64, str, 0) catch |err| {
                            const msg = "{!} when processing type = 'int' arg = '{s}' and value = '{s}'\n";
                            std.log.err(msg, .{ err, name, str });
                            return err;
                        },
                    },
                    ArgType.Float => ArgValue{ .float = std.fmt.parseFloat(f64, str) catch |err| {
                        const msg = "{!} when processing type = 'float' arg = '{s}' and value = '{s}'\n";
                        std.log.err(msg, .{ err, name, str });
                        return err;
                    } },
                    ArgType.String => ArgValue{ .string = str },
                    else => continue,
                };
                try self.values.put(spec.name, value);
                state = .arg_expected;
            }
        }
    }

    const ArgState = enum { arg_expected, value_expected };
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

pub const ArgValue = union {
    int: i64,
    float: f64,
    bool: bool,
    string: []const u8,
};

pub const ArgType = enum { Int, Float, Bool, String };
pub const ArgAction = enum { store, append, store_true, store_false, count };
pub const ArgError = error{InvalidBool};

// #####################################################################################
// tests
// #####################################################################################
//
const expect = std.testing.expect;

fn initParser(allocator: std.mem.Allocator) !ArgParser {
    var parser = try ArgParser.init(.{
        .allocator = allocator,
        .header = "Testing",
    });
    try parser.add(.{
        .type = .Int,
        .default = ArgValue{ .int = 42 },
        .name = "-test",
    });
    return parser;
}

test "happy happy" {
    const allocator = std.testing.allocator;
    var parser = try initParser(allocator);
    defer parser.deinit();
}

test "parse an int" {
    const allocator = std.testing.allocator;
    var parser = try initParser(allocator);
    defer parser.deinit();

    const args: []const []const u8 = &.{ "prog", "-test", "420" };
    try parser.parseStrings(args);

    const actual = parser.values.get("-test").?.int;
    try expect(actual == 420);
}

test "parse an invalid int" {
    const allocator = std.testing.allocator;
    var parser = try initParser(allocator);
    defer parser.deinit();

    const args: []const []const u8 = &.{ "prog", "-test", "bad20" };
    try std.testing.expectError(error.InvalidCharacter, parser.parseStrings(args));
}
