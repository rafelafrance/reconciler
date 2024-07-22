const std = @import("std");

const arg_parser = @import("arg_parser.zig");
const csv_parser = @import("csv_parser.zig");
const nfn_parser = @import("nfn_parser.zig");

const ArgValue = arg_parser.ArgValue;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    errdefer std.process.exit(1);

    var args = try arg_parser.ArgParser.init(.{
        .allocator = allocator,
        .header = "Testing header",
    });
    try args.add(.{
        .type = .Int,
        .default = ArgValue{ .int = 42 },
        .name = "-test",
    });
    try args.parse();

    var nfn_csv = try csv_parser.CsvParser.init(.{ .allocator = allocator });

    const data = try std.fs.cwd().readFileAlloc(
        allocator,
        "data/raw/classifications.csv",
        10_000_000,
    );
    try nfn_csv.parseString(data);

    const nfn = try nfn_parser.NfnParser.init(.{
        .allocator = allocator,
        .csv_parser = nfn_csv,
    });
    _ = nfn;
}
