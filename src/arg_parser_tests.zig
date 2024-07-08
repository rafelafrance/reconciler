const std = @import("std");
const arg_parser = @import("arg_parser.zig");
usingnamespace std.testing;

fn init_parser(allocator: std.mem.Allocator) !arg_parser.ArgParser {
    var parser = try arg_parser.ArgParser.init(.{
        .allocator = allocator,
        .header = "Testing",
    });
    try parser.add(.{
        .type = .Int,
        .default = arg_parser.ArgValue{ .Int = 42 },
        .name = "-test",
    });
    return parser;
}

test "happy happy" {
    const allocator = std.testing.allocator;
    var parser = try init_parser(allocator);
    defer parser.deinit();
}

test "easy parse" {
    const allocator = std.testing.allocator;
    var parser = try init_parser(allocator);
    defer parser.deinit();

    const args: []const []const u8 = &.{ "prog", "-test", "tee" };
    try parser.parse_strings(args);
}
