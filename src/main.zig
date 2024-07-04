const std = @import("std");

const arg_parser = @import("arg_parser.zig");
const ArgParser = arg_parser.ArgParser;
const ArgValue = arg_parser.ArgValue;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const parser = ArgParser{
        .allocator = allocator,
        .header = "Testing",
        .args = &.{
            .{
                .type = .Int,
                .default = ArgValue{ .Int = 42 },
                .names = &.{ "-test", "-t" },
            },
        },
    };

    try parser.parse();
}
