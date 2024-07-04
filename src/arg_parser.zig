const std = @import("std");

pub const Arg = struct {
    type: ArgType,
    names: []const []const u8,
    action: ArgAction = .store,
    required: bool = false,
    help: []const u8 = "",
    default: ?ArgValue = null,
};

pub const ArgParser = struct {
    allocator: std.mem.Allocator,
    header: []const u8 = "",
    footer: []const u8 = "",
    args: []const Arg,

    pub fn parse(self: ArgParser) !void {
        const args = try std.process.argsAlloc(self.allocator);
        defer std.process.argsFree(self.allocator, args);
        for (args) |arg| {
            std.debug.print("arg: {s}\n", .{arg});
        }
    }
};

pub const ArgValue = union(ArgType) {
    Int: i64,
    Float: f64,
    Bool: bool,
    String: []const u8,
};

pub const ArgType = enum { Int, Float, Bool, String };
pub const ArgAction = enum { store, append, count, store_true, store_false };
pub const ArgError = error{};

test "happy case" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const arg_parser = ArgParser{
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

    try arg_parser.parse();
}
