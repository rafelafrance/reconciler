const std = @import("std");

const args_ = @import("args/args.zig");
const ArgValue = args_.ArgValue;

const csv_ = @import("csv/csv.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.detectLeaks();

    const allocator = gpa.allocator();

    var args = try args_.Args.init(.{
        .allocator = allocator,
        .header = "Testing header",
    });
    defer args.deinit();
    errdefer std.process.exit(1);

    try args.add(.{
        .type = .Int,
        .default = ArgValue{ .int = 42 },
        .name = "-test",
    });

    try args.parse();

    var csv_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer csv_arena.deinit();
    const csv_alloc = csv_arena.allocator();

    var csv = try csv_.Csv.init(.{ .allocator = csv_alloc });

    const data = try std.fs.cwd().readFileAlloc(
        csv_alloc,
        "data/raw/classifications.csv",
        10_000_000,
    );
    try csv.parseString(data);

    std.debug.print("data.len {}\n", .{data.len});
    std.debug.print("csv [{},{}]\n", .{ csv.rows, csv.cols });
    for (0..csv.cols) |c| std.debug.print("{s}\n", .{try csv.cellValue(0, c)});
}
