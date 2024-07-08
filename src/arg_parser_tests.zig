const std = @import("std");
const arg_parser = @import("arg_parser.zig");
const expect = std.testing.expect;

fn init_parser(allocator: std.mem.Allocator) !arg_parser.ArgParser {
    var parser = try arg_parser.ArgParser.init(.{
        .allocator = allocator,
        .header = "Testing",
    });
    try parser.add(.{
        .type = .Int,
        .default = arg_parser.ArgValue{ .int = 42 },
        .name = "-test",
    });
    return parser;
}

test "happy happy" {
    const allocator = std.testing.allocator;
    var parser = try init_parser(allocator);
    defer parser.deinit();
}

test "parse an int" {
    const allocator = std.testing.allocator;
    var parser = try init_parser(allocator);
    defer parser.deinit();

    const args: []const []const u8 = &.{ "prog", "-test", "420" };
    try parser.parse_strings(args);

    const actual = parser.values.get("-test").?.int;
    try expect(actual == 420);
}
