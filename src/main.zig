const std = @import("std");

const arg_parser = @import("arg_parser/arg_parser.zig");
const ArgParser = arg_parser.ArgParser;
const ArgValue = arg_parser.ArgValue;

const csv_reader = @import("csv_reader/csv_reader.zig");
const CsvReader = csv_reader.CsvReader;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.detectLeaks();

    const allocator = gpa.allocator();

    var parser = try ArgParser.init(.{
        .allocator = allocator,
        .header = "Testing header",
    });
    errdefer std.process.exit(1);
    defer parser.deinit();

    try parser.add(.{
        .type = .Int,
        .default = arg_parser.ArgValue{ .int = 42 },
        .name = "-test",
    });

    try parser.parse();

    const name = "data/raw/test.csv";
    var reader = try CsvReader.init(.{
        .allocator = allocator,
        .path = "/srv/work/rafe/nfn/zig_label_reconciliations/" ++ name, // test absolute
        // .path = name, // test relative
    });
    defer reader.deinit();
    try reader.read();
}
