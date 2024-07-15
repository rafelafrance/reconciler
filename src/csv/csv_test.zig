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

    try expect(eql(u8, try csv.cell(0, 0), "zero"));
    try expect(eql(u8, try csv.cell(1, 0), "one"));
    try expect(eql(u8, try csv.cell(2, 0), "two"));
    try expect(eql(u8, try csv.cell(3, 0), "three"));
    try expect(eql(u8, try csv.cell(4, 0), "four"));
}
// test "it handles quotes" {
//     const allocator = std.testing.allocator;
//     var csv = try csv_.Csv.init(.{ .allocator = allocator, .path = "" });
//     defer csv.deinit();
//
//     const target: []u8 = @constCast("\"\"\"zero\"\"\",\"\"\"\",\"\"\"\"\"\",th\"\"re\"\"e");
//     try csv.scan(target, target.len);
//
//     const slice = try csv.cells.toOwnedSlice();
//     defer deinit_owned_slice(allocator, slice);
//
//     try expect(slice.len == 4);
//     try expect_item(slice[0], @constCast("\"zero\""), 0, 0);
//     try expect_item(slice[1], @constCast("\""), 0, 1);
//     try expect_item(slice[2], @constCast("\"\""), 0, 2);
//     try expect_item(slice[3], @constCast("th\"re\"e"), 0, 3);
// }
// test "it handles multiple lines" {
//     const allocator = std.testing.allocator;
//     var csv = try csv_.Csv.init(.{ .allocator = allocator, .path = "" });
//     defer csv.deinit();
//
//     const target: []u8 = @constCast("one\ntwo");
//     try csv.scan(target, target.len);
//
//     const slice = try csv.cells.toOwnedSlice();
//     defer deinit_owned_slice(allocator, slice);
//
//     try expect(slice.len == 2);
//     try expect(eql(u8, slice[0].val, "one"));
//     try expect(eql(u8, slice[1].val, "two"));
// }
// test "it handles an empty string" {
//     const allocator = std.testing.allocator;
//     var csv = try csv_.Csv.init(.{ .allocator = allocator, .path = "" });
//     defer csv.deinit();
//
//     const target: []u8 = @constCast("");
//     try csv.scan(target, target.len);
//
//     try expect(csv.cells.items.len == 0);
// }
// test "it handles empty cells" {
//     const allocator = std.testing.allocator;
//     var csv = try csv_.Csv.init(.{ .allocator = allocator, .path = "" });
//     defer csv.deinit();
//
//     const target: []u8 = @constCast(",,\n,,");
//     try csv.scan(target, target.len);
//
//     const slice = try csv.cells.toOwnedSlice();
//     defer deinit_owned_slice(allocator, slice);
//
//     // print("{}\n", .{slice.len});
//     // for (slice) |i| print("{any}\n", .{i});
//
//     try expect(slice.len == 6);
//     try expect_item(slice[0], @constCast(""), 0, 0);
//     try expect_item(slice[1], @constCast(""), 0, 1);
//     try expect_item(slice[2], @constCast(""), 0, 2);
//     try expect_item(slice[3], @constCast(""), 1, 0);
//     try expect_item(slice[4], @constCast(""), 1, 1);
//     try expect_item(slice[5], @constCast(""), 1, 2);
// }
