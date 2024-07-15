const std = @import("std");
const args_ = @import("args.zig");
const expect = std.testing.expect;

fn initParser(allocator: std.mem.Allocator) !args_.Args {
    var parser = try args_.Args.init(.{ .allocator = allocator, .header = "Testing" });
    try parser.add(.{
        .type = .Int,
        .default = args_.ArgValue{ .int = 42 },
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
