const std = @import("std");

const arg_parser = @import("args/arg_parser.zig");
const ArgParser = arg_parser.ArgParser;
const ArgValue = arg_parser.ArgValue;

const csv_reader = @import("csv_reader/csv_reader.zig");
const Csv = csv_reader.CsvReader;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.detectLeaks();

    const allocator = gpa.allocator();

    var args = try ArgParser.init(.{
        .allocator = allocator,
        .header = "Testing header",
    });
    // errdefer std.process.exit(1);
    defer args.deinit();

    try args.add(.{
        .type = .Int,
        .default = arg_parser.ArgValue{ .int = 42 },
        .name = "-test",
    });

    try args.parse();

    var csv_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer csv_arena.deinit();
    const csv_alloc = csv_arena.allocator();

    var csv = try Csv.init(.{
        .allocator = csv_alloc,
        .path = "data/raw/test.csv",
    });
    try csv.read();
}
