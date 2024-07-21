const std = @import("std");
const csv_ = @import("csv.zig");

const print = std.debug.print;
const expect = std.testing.expect;
const eql = std.mem.eql;

test "test various line endings" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator });
    defer csv.deinit();

    const target: []u8 = @constCast("zero\r\n" ++ "one\r" ++ "two\n" ++ "three\n\r" ++ "four");
    try csv.parseString(target);

    try expect(csv.rows == 5);
    try expect(csv.cols == 1);
    try expect(eql(u8, csv.get(0, 0).?, "zero"));
    try expect(eql(u8, csv.get(1, 0).?, "one"));
    try expect(eql(u8, csv.get(2, 0).?, "two"));
    try expect(eql(u8, csv.get(3, 0).?, "three"));
    try expect(eql(u8, csv.get(4, 0).?, "four"));
}
test "it handles an eol at the end of the file" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator });
    defer csv.deinit();

    const target: []u8 = @constCast("zero\r\n");
    try csv.parseString(target);

    try expect(csv.rows == 1);
    try expect(csv.cols == 1);
    try expect(eql(u8, csv.get(0, 0).?, "zero"));
}
test "it handles quotes" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator });
    defer csv.deinit();

    const target: []u8 = @constCast("\"\"\"zero\"\"\"" ++ ",\"\"\"\"" ++ ",\"\"\"\"\"\"" ++ ",th\"\"re\"\"e");
    try csv.parseString(target);

    try expect(csv.rows == 1);
    try expect(csv.cols == 4);
    try expect(eql(u8, csv.get(0, 0).?, "\"zero\""));
    try expect(eql(u8, csv.get(0, 1).?, "\""));
    try expect(eql(u8, csv.get(0, 2).?, "\"\""));
    try expect(eql(u8, csv.get(0, 3).?, "th\"re\"e"));
}
test "it handles an empty string" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator });
    defer csv.deinit();

    const target: []u8 = @constCast("");
    try csv.parseString(target);

    try expect(csv.rows == 1);
    try expect(csv.cols == 1);
    try expect(csv.get(0, 0) == null);
}
test "it handles empty cells" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator });
    defer csv.deinit();

    const target: []u8 = @constCast(",,\n" ++ ",,\n");
    try csv.parseString(target);

    try expect(csv.rows == 2);
    try expect(csv.cols == 3);
    try expect(csv.get(0, 0) == null);
    try expect(csv.get(0, 1) == null);
    try expect(csv.get(0, 2) == null);
    try expect(csv.get(1, 0) == null);
    try expect(csv.get(1, 1) == null);
    try expect(csv.get(1, 2) == null);
}
test "it handles empty cells part2" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator });
    defer csv.deinit();

    const target: []u8 = @constCast(",,");
    try csv.parseString(target);

    try expect(csv.rows == 1);
    try expect(csv.cols == 3);
    try expect(csv.get(0, 0) == null);
    try expect(csv.get(0, 1) == null);
    try expect(csv.get(0, 2) == null);
}
test "it handles eols and commas inside of quotes" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator });
    defer csv.deinit();

    const target: []u8 = @constCast("\",\n,\r\n\"");
    try csv.parseString(target);

    try expect(csv.rows == 1);
    try expect(csv.cols == 1);
    try expect(eql(u8, csv.get(0, 0).?, ",\n,\r\n"));
}
test "it handles ragged rows" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator });
    defer csv.deinit();

    const target: []u8 = @constCast("zero,one,two\r\n" ++ "three");
    try csv.parseString(target);

    try expect(csv.rows == 2);
    try expect(csv.cols == 3);
    try expect(eql(u8, csv.get(0, 0).?, "zero"));
    try expect(eql(u8, csv.get(0, 1).?, "one"));
    try expect(eql(u8, csv.get(0, 2).?, "two"));
    try expect(eql(u8, csv.get(1, 0).?, "three"));
    try expect(csv.get(1, 1) == null);
    try expect(csv.get(1, 2) == null);
}
test "it handles empty rows" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator });
    defer csv.deinit();

    const target: []u8 = @constCast("zero,one\r\n" ++ "\n" ++ "\n" ++ "two");
    try csv.parseString(target);

    try expect(csv.rows == 4);
    try expect(csv.cols == 2);
    try expect(eql(u8, csv.get(0, 0).?, "zero"));
    try expect(eql(u8, csv.get(0, 1).?, "one"));
    try expect(csv.get(1, 0) == null);
    try expect(csv.get(1, 1) == null);
    try expect(csv.get(2, 0) == null);
    try expect(csv.get(2, 1) == null);
    try expect(eql(u8, csv.get(3, 0).?, "two"));
    try expect(csv.get(3, 1) == null);
}
test "it finds values in a row" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator });
    defer csv.deinit();

    const target: []u8 = @constCast("zero,one,\r\n" ++ "three,,five");
    try csv.parseString(target);

    try expect(csv.firstInRow(0, @constCast("zero")) == 0);
    try expect(csv.firstInRow(0, @constCast("one")) == 1);
    try expect(csv.firstInRow(0, @constCast("two")) == null);
    try expect(csv.firstInRow(0, @constCast("three")) == null);
    try expect(csv.firstInRow(1, @constCast("three")) == 0);
    try expect(csv.firstInRow(1, @constCast("four")) == null);
    try expect(csv.firstInRow(1, @constCast("five")) == 2);
}
test "it handles different delimiters" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator, .delimiter = '\t' });
    defer csv.deinit();

    const target: []u8 = @constCast("zero\t" ++ "one\n" ++ "two\t" ++ "three");
    try csv.parseString(target);

    try expect(csv.rows == 2);
    try expect(csv.cols == 2);
    try expect(eql(u8, csv.get(0, 0).?, "zero"));
    try expect(eql(u8, csv.get(0, 1).?, "one"));
    try expect(eql(u8, csv.get(1, 0).?, "two"));
    try expect(eql(u8, csv.get(1, 1).?, "three"));
}
test "you may call parse more than once" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator });
    defer csv.deinit();

    const target0: []u8 = @constCast("zero," ++ "one\n");
    try csv.parseString(target0);

    try expect(csv.rows == 1);
    try expect(csv.cols == 2);
    try expect(eql(u8, csv.get(0, 0).?, "zero"));
    try expect(eql(u8, csv.get(0, 1).?, "one"));

    const target1: []u8 = @constCast("two," ++ "three\n");
    try csv.parseString(target1);

    try expect(csv.rows == 1);
    try expect(csv.cols == 2);
    try expect(eql(u8, csv.get(0, 0).?, "two"));
    try expect(eql(u8, csv.get(0, 1).?, "three"));

    const target2: []u8 = @constCast("four," ++ "five," ++ "six");
    try csv.parseString(target2);

    try expect(csv.rows == 1);
    try expect(csv.cols == 3);
    try expect(eql(u8, csv.get(0, 0).?, "four"));
    try expect(eql(u8, csv.get(0, 1).?, "five"));
    try expect(eql(u8, csv.get(0, 2).?, "six"));
}
test "it trims spaces" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator });
    defer csv.deinit();

    const target: []u8 = @constCast(" zero , one, two ,\" three \"");
    try csv.parseString(target);

    try expect(csv.rows == 1);
    try expect(csv.cols == 4);
    try expect(eql(u8, csv.get(0, 0).?, "zero"));
    try expect(eql(u8, csv.get(0, 1).?, "one"));
    try expect(eql(u8, csv.get(0, 2).?, "two"));
    try expect(eql(u8, csv.get(0, 3).?, " three "));
}
test "it handles spaces around quoted fields" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator });
    defer csv.deinit();

    const target: []u8 = @constCast(" \" zero\"  ," ++ "\"one \" \n" ++ " \" two \" ," ++ "  ");
    try csv.parseString(target);

    try expect(csv.rows == 2);
    try expect(csv.cols == 2);
    try expect(eql(u8, csv.get(0, 0).?, " zero"));
    try expect(eql(u8, csv.get(0, 1).?, "one "));
    try expect(eql(u8, csv.get(1, 0).?, " two "));
    try expect(csv.get(1, 1) == null);
}
test "let's see what it does with broken quoted fields" {
    const allocator = std.testing.allocator;
    var csv = try csv_.Csv.init(.{ .allocator = allocator });
    defer csv.deinit();

    const target: []u8 = @constCast("\"zero ,\n ");
    try csv.parseString(target);

    try expect(csv.rows == 1);
    try expect(csv.cols == 1);
    try expect(eql(u8, csv.get(0, 0).?, "zero ,\n "));
    try expect(csv.get(1, 1) == null);
}
