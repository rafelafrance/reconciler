const std = @import("std");
const csv_ = @import("csv.zig");

const print = std.debug.print;
const expect = std.testing.expect;
const eql = std.mem.eql;

test "test various line endings" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator, .path = "" });
    defer csv.deinit();

    const target: []u8 = @constCast("zero\r\none\rtwo\nthree\n\rfour");
    try csv.scan(target, target.len);

    try expect(csv.rows == 5);
    try expect(csv.cols == 1);
    try expect(eql(u8, try csv.cell(0, 0), "zero"));
    try expect(eql(u8, try csv.cell(1, 0), "one"));
    try expect(eql(u8, try csv.cell(2, 0), "two"));
    try expect(eql(u8, try csv.cell(3, 0), "three"));
    try expect(eql(u8, try csv.cell(4, 0), "four"));
}
test "it handles quotes" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator, .path = "" });
    defer csv.deinit();

    const target: []u8 = @constCast("\"\"\"zero\"\"\",\"\"\"\",\"\"\"\"\"\",th\"\"re\"\"e");
    try csv.scan(target, target.len);

    try expect(csv.rows == 1);
    try expect(csv.cols == 4);
    try expect(eql(u8, try csv.cell(0, 0), "\"zero\""));
    try expect(eql(u8, try csv.cell(0, 1), "\""));
    try expect(eql(u8, try csv.cell(0, 2), "\"\""));
    try expect(eql(u8, try csv.cell(0, 3), "th\"re\"e"));
}
test "it handles an empty string" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator, .path = "" });
    defer csv.deinit();

    const target: []u8 = @constCast("");
    try csv.scan(target, target.len);

    try expect(csv.rows == 1);
    try expect(csv.cols == 1);
    try expect(eql(u8, try csv.cell(0, 0), ""));
}
test "it handles empty cells" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator, .path = "" });
    defer csv.deinit();

    const target: []u8 = @constCast(",,\n,,\n");
    try csv.scan(target, target.len);

    try expect(csv.rows == 2);
    try expect(csv.cols == 3);
    try expect(eql(u8, try csv.cell(0, 0), ""));
    try expect(eql(u8, try csv.cell(0, 1), ""));
    try expect(eql(u8, try csv.cell(0, 2), ""));
    try expect(eql(u8, try csv.cell(1, 0), ""));
    try expect(eql(u8, try csv.cell(1, 1), ""));
    try expect(eql(u8, try csv.cell(1, 2), ""));
}
test "it handles empty cells part2" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator, .path = "" });
    defer csv.deinit();

    const target: []u8 = @constCast(",,");
    try csv.scan(target, target.len);

    try expect(csv.rows == 1);
    try expect(csv.cols == 3);
    try expect(eql(u8, try csv.cell(0, 0), ""));
    try expect(eql(u8, try csv.cell(0, 1), ""));
    try expect(eql(u8, try csv.cell(0, 2), ""));
}
test "it handles eols and commas inside of quotes" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator, .path = "" });
    defer csv.deinit();

    const target: []u8 = @constCast("\",\n,\r\n\"");
    try csv.scan(target, target.len);

    try expect(csv.rows == 1);
    try expect(csv.cols == 1);
    try expect(eql(u8, try csv.cell(0, 0), ",\n,\r\n"));
}
test "it handles an eol at the end of the file" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator, .path = "" });
    defer csv.deinit();

    const target: []u8 = @constCast("zero\r\n");
    try csv.scan(target, target.len);

    try expect(csv.rows == 1);
    try expect(csv.cols == 1);
    try expect(eql(u8, try csv.cell(0, 0), "zero"));
}
test "it handles ragged rows" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator, .path = "" });
    defer csv.deinit();

    const target: []u8 = @constCast("zero,one,two\r\nthree");
    try csv.scan(target, target.len);

    try expect(csv.rows == 2);
    try expect(csv.cols == 3);
    try expect(eql(u8, try csv.cell(0, 0), "zero"));
    try expect(eql(u8, try csv.cell(0, 1), "one"));
    try expect(eql(u8, try csv.cell(0, 2), "two"));
    try expect(eql(u8, try csv.cell(1, 0), "three"));
    try expect(eql(u8, try csv.cell(1, 1), ""));
    try expect(eql(u8, try csv.cell(1, 2), ""));
}
