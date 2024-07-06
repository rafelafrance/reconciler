const std = @import("std");
const ap = @import("arg_parser.zig");
usingnamespace std.testing;

test "happy happy" {
    const allocator = std.testing.allocator;

    var parser = try ap.ArgParser.init(.{
        .allocator = allocator,
        .header = "Testing",
        .specs = &.{
            .{
                .type = .Int,
                .default = ap.ArgValue{ .Int = 42 },
                .names = &.{ "-test", "-t" },
            },
        },
    });
    defer parser.deinit();
}

test "easy parse" {
    const allocator = std.testing.allocator;

    var parser = try ap.ArgParser.init(.{
        .allocator = allocator,
        .header = "Testing",
        .specs = &.{
            .{
                .type = .Int,
                .default = ap.ArgValue{ .Int = 42 },
                .names = &.{ "-test", "-t" },
            },
        },
    });
    defer parser.deinit();
    const args: []const []const u8 = &.{ "prog", "-t", "tee" };
    try parser.parse_strings(args);
}
