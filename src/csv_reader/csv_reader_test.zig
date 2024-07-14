const std = @import("std");
const csv_reader = @import("csv_reader.zig");

const print = std.debug.print;
const expect = std.testing.expect;
const eql = std.mem.eql;

fn deinit_owned_slice(allocator: std.mem.Allocator, slice: []*csv_reader.Cell) void {
    for (slice) |cell| {
        allocator.free(cell.buff);
        allocator.destroy(cell);
    }
    allocator.free(slice);
}

fn expect_item(cell: *csv_reader.Cell, val: []u8, row: isize, col: isize) !void {
    try expect(eql(u8, cell.val, val));
    try expect(cell.row == row);
    try expect(cell.col == col);
}

test "test various line endings" {
    const allocator = std.testing.allocator;
    var reader = try csv_reader.CsvReader.init(.{ .allocator = allocator, .path = "" });
    defer reader.deinit();

    const target: []u8 = @constCast("zero\r\none\rtwo\nthree\n\rfour");
    try reader.scan(target, target.len);

    const slice = try reader.cells.toOwnedSlice();
    defer deinit_owned_slice(allocator, slice);

    // print("{}\n", .{slice.len});
    // for (slice) |i| print("{any}\n", .{i});

    try expect(slice.len == 5);
    try expect_item(slice[0], @constCast("zero"), 0, 0);
    try expect_item(slice[1], @constCast("one"), 1, 0);
    try expect_item(slice[2], @constCast("two"), 2, 0);
    try expect_item(slice[3], @constCast("three"), 3, 0);
    try expect_item(slice[4], @constCast("four"), 4, 0);
}
test "it handles quotes" {
    const allocator = std.testing.allocator;
    var reader = try csv_reader.CsvReader.init(.{ .allocator = allocator, .path = "" });
    defer reader.deinit();

    const target: []u8 = @constCast("\"\"\"zero\"\"\",\"\"\"\",\"\"\"\"\"\",th\"\"re\"\"e");
    try reader.scan(target, target.len);

    const slice = try reader.cells.toOwnedSlice();
    defer deinit_owned_slice(allocator, slice);

    try expect(slice.len == 4);
    try expect_item(slice[0], @constCast("\"zero\""), 0, 0);
    try expect_item(slice[1], @constCast("\""), 0, 1);
    try expect_item(slice[2], @constCast("\"\""), 0, 2);
    try expect_item(slice[3], @constCast("th\"re\"e"), 0, 3);
}
test "it handles multiple lines" {
    const allocator = std.testing.allocator;
    var reader = try csv_reader.CsvReader.init(.{ .allocator = allocator, .path = "" });
    defer reader.deinit();

    const target: []u8 = @constCast("one\ntwo");
    try reader.scan(target, target.len);

    const slice = try reader.cells.toOwnedSlice();
    defer deinit_owned_slice(allocator, slice);

    try expect(slice.len == 2);
    try expect(eql(u8, slice[0].val, "one"));
    try expect(eql(u8, slice[1].val, "two"));
}
test "it handles an empty string" {
    const allocator = std.testing.allocator;
    var reader = try csv_reader.CsvReader.init(.{ .allocator = allocator, .path = "" });
    defer reader.deinit();

    const target: []u8 = @constCast("");
    try reader.scan(target, target.len);

    try expect(reader.cells.items.len == 0);
}
test "it handles empty cells" {
    const allocator = std.testing.allocator;
    var reader = try csv_reader.CsvReader.init(.{ .allocator = allocator, .path = "" });
    defer reader.deinit();

    const target: []u8 = @constCast(",,\n,,");
    try reader.scan(target, target.len);

    const slice = try reader.cells.toOwnedSlice();
    defer deinit_owned_slice(allocator, slice);

    // print("{}\n", .{slice.len});
    // for (slice) |i| print("{any}\n", .{i});

    try expect(slice.len == 6);
    try expect_item(slice[0], @constCast(""), 0, 0);
    try expect_item(slice[1], @constCast(""), 0, 1);
    try expect_item(slice[2], @constCast(""), 0, 2);
    try expect_item(slice[3], @constCast(""), 1, 0);
    try expect_item(slice[4], @constCast(""), 1, 1);
    try expect_item(slice[5], @constCast(""), 1, 2);
}
