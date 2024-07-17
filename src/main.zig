const std = @import("std");

const args_ = @import("args/args.zig");
const ArgValue = args_.ArgValue;

const csv_ = @import("csv/csv.zig");

const nfn_ = @import("nfn/nfn.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    errdefer std.process.exit(1);

    var args = try args_.Args.init(.{
        .allocator = allocator,
        .header = "Testing header",
    });

    try args.add(.{
        .type = .Int,
        .default = ArgValue{ .int = 42 },
        .name = "-test",
    });

    try args.parse();

    var csv = try csv_.Csv.init(.{ .allocator = allocator });

    const data = try std.fs.cwd().readFileAlloc(
        allocator,
        "data/raw/classifications.csv",
        10_000_000,
    );
    try csv.parseString(data);

    const nfn = try nfn_.Nfn.init(.{ .allocator = allocator, .csv = csv });
    _ = nfn;
}
