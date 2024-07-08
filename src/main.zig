const std = @import("std");

const arg_parser = @import("arg_parser.zig");
const ArgParser = arg_parser.ArgParser;
const ArgValue = arg_parser.ArgValue;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.detectLeaks();

    const allocator = gpa.allocator();

    var parser = try ArgParser.init(.{
        .allocator = allocator,
        .header = "Testing header",
    });
    defer parser.deinit();

    try parser.add(.{
        .type = .Int,
        .default = arg_parser.ArgValue{ .Int = 42 },
        .name = "-test",
    });

    try parser.parse();
}
