//! This is a minimal CSV parser library.
//! Input a string and parse it into rows and columns.
//! Output a grid/rectangle of optional slice pointers.
//! I try not to deviate from RFC 4180, and handle some weird stuff that I've seen.

const std = @import("std");

pub const CsvParser = struct {
    allocator: std.mem.Allocator,
    delimiter: u8, // record delimiter
    table: []?[]u8 = undefined, // holds CSV string slice pointers. This is the payload
    raw_cells: std.ArrayList(*RawCell), // list of parsed CSV cells. blank cell/rows are skipped
    rows: usize = 1, // total number of rows in CSV file AFTER parsing
    cols: usize = 1, // maximum number of columns in a row (CSVs rows may be ragged)
    dirty: bool = false, // used with repeated calls to parse()

    pub fn init(config: struct {
        allocator: std.mem.Allocator,
        delimiter: u8 = ',',
    }) !CsvParser {
        return CsvParser{
            .allocator = config.allocator,
            .delimiter = config.delimiter,
            .raw_cells = std.ArrayList(*RawCell).init(config.allocator),
        };
    }

    pub fn deinit(self: *CsvParser) void {
        self.allocator.free(self.table);
        for (self.raw_cells.items) |item| {
            self.allocator.free(item.buff);
            self.allocator.destroy(item);
        }
        self.raw_cells.deinit();
    }

    /// Turn a 2D address into a linear address
    pub inline fn index(self: CsvParser, row: usize, col: usize) usize {
        return row * self.cols + col;
    }

    pub inline fn inBounds(self: CsvParser, row: usize, col: usize) bool {
        return row < self.rows and col < self.cols;
    }

    /// Get the contents of a cell.
    pub fn get(self: CsvParser, row: usize, col: usize) ?[]u8 {
        if (!self.inBounds(row, col)) return null;
        return self.table[self.index(row, col)];
    }

    /// Find the first occurrence of the given string in a row and return its index.
    /// I use this to look for headers.
    pub fn firstInRow(self: CsvParser, row: usize, value: []u8) ?usize {
        for (0..self.cols) |col| {
            const cell_value = self.get(row, col) orelse continue;
            if (std.mem.eql(u8, cell_value, value)) return col;
        }
        return null;
    }

    // Convert a string into a CSV table.
    // A table is nothing more than a grid of optional string slices.
    pub fn parseString(self: *CsvParser, str: []u8) !void {
        self.clear();
        const last_idx = if (str.len > 0) str.len - 1 else 0;

        const array = [_]u8{ self.delimiter, '\r', '\n' };
        const enders = array[0..]; // Chars at the end a cell

        var coords = Coords{};
        var pos: usize = 0;

        while (pos < str.len) {
            if (str[pos] == self.delimiter) {
                pos += 1; // skip delimiter
                coords.nextCol(self);
            } else if (CsvParser.isEol(str[pos])) {
                pos += 1; // skip eol
                if (pos < last_idx) {
                    if (CsvParser.isEol(str[pos]) and str[pos - 1] != str[pos]) pos += 1; // skip eol
                    coords.nextRow(self);
                }
            } else if (str[pos] == ' ') {
                pos = std.mem.indexOfNonePos(u8, str, pos, " ") orelse str.len;
            } else if (str[pos] == '"') {
                pos += 1; // skip starting quote
                var end = std.mem.indexOfScalarPos(u8, str, pos, '"') orelse str.len;
                while (end < last_idx and str[end + 1] == '"') {
                    end = std.mem.indexOfScalarPos(u8, str, end + 2, '"').?;
                }
                try self.appendRawCell(str[pos..end], coords, true);
                pos = end + 1; // skip ending quote
            } else {
                const end = std.mem.indexOfAnyPos(u8, str, pos, enders) orelse str.len;
                try self.appendRawCell(str[pos..end], coords, false);
                pos = end; // skip passed field
            }
        }
        try self.createTable();
    }

    fn appendRawCell(self: *CsvParser, raw: []u8, coords: Coords, quoted: bool) !void {
        const cell = try self.allocator.create(RawCell);

        var buff = try self.allocator.alloc(u8, raw.len);
        const n = std.mem.replace(u8, raw, "\"\"", "\"", buff);
        const slice = buff[0 .. raw.len - n];

        cell.* = RawCell{
            .row = coords.row,
            .col = coords.col,
            .buff = buff,
            .val = if (quoted) slice else @constCast(std.mem.trimRight(u8, slice, " ")),
        };

        try self.raw_cells.append(cell);
    }

    fn createTable(self: *CsvParser) !void {
        self.table = try self.allocator.alloc(?[]u8, self.rows * self.cols);
        for (self.table) |*cell| cell.* = null;
        for (self.raw_cells.items) |item| {
            self.table[self.index(item.row, item.col)] = item.val;
        }
    }

    fn clear(self: *CsvParser) void {
        if (self.dirty) {
            self.rows = 1;
            self.cols = 1;

            self.allocator.free(self.table);

            for (self.raw_cells.items) |item| {
                self.allocator.free(item.buff);
                self.allocator.destroy(item);
            }
            self.raw_cells.clearRetainingCapacity();
        }

        self.dirty = true;
    }

    inline fn isEol(char: u8) bool {
        return char == '\r' or char == '\n';
    }

    const Coords = struct {
        row: usize = 0,
        col: usize = 0,

        fn nextRow(self: *Coords, csv: *CsvParser) void {
            self.row += 1;
            self.col = 0;
            csv.rows = self.row + 1;
        }

        fn nextCol(self: *Coords, csv: *CsvParser) void {
            self.col += 1;
            const col = self.col + 1;
            if (col > csv.cols) csv.cols = col;
        }
    };

    const RawCell = struct {
        row: usize,
        col: usize,
        buff: []u8,
        val: []u8,
    };
};

// #####################################################################################
// tests
// #####################################################################################
//
const expect = std.testing.expect;
const eql = std.mem.eql;

test "test various line endings" {
    const allocator = std.testing.allocator;
    var csv = try CsvParser.init(.{ .allocator = allocator });
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
    var csv = try CsvParser.init(.{ .allocator = allocator });
    defer csv.deinit();

    const target: []u8 = @constCast("zero\r\n");
    try csv.parseString(target);

    try expect(csv.rows == 1);
    try expect(csv.cols == 1);
    try expect(eql(u8, csv.get(0, 0).?, "zero"));
}
test "it handles quotes" {
    const allocator = std.testing.allocator;
    var csv = try CsvParser.init(.{ .allocator = allocator });
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
    var csv = try CsvParser.init(.{ .allocator = allocator });
    defer csv.deinit();

    const target: []u8 = @constCast("");
    try csv.parseString(target);

    try expect(csv.rows == 1);
    try expect(csv.cols == 1);
    try expect(csv.get(0, 0) == null);
}
test "it handles empty cells" {
    const allocator = std.testing.allocator;
    var csv = try CsvParser.init(.{ .allocator = allocator });
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
    var csv = try CsvParser.init(.{ .allocator = allocator });
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
    var csv = try CsvParser.init(.{ .allocator = allocator });
    defer csv.deinit();

    const target: []u8 = @constCast("\",\n,\r\n\"");
    try csv.parseString(target);

    try expect(csv.rows == 1);
    try expect(csv.cols == 1);
    try expect(eql(u8, csv.get(0, 0).?, ",\n,\r\n"));
}
test "it handles ragged rows" {
    const allocator = std.testing.allocator;
    var csv = try CsvParser.init(.{ .allocator = allocator });
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
    var csv = try CsvParser.init(.{ .allocator = allocator });
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
    var csv = try CsvParser.init(.{ .allocator = allocator });
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
    var csv = try CsvParser.init(.{ .allocator = allocator, .delimiter = '\t' });
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
    var csv = try CsvParser.init(.{ .allocator = allocator });
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
    var csv = try CsvParser.init(.{ .allocator = allocator });
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
    var csv = try CsvParser.init(.{ .allocator = allocator });
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
    var csv = try CsvParser.init(.{ .allocator = allocator });
    defer csv.deinit();

    const target: []u8 = @constCast("\"zero ,\n ");
    try csv.parseString(target);

    try expect(csv.rows == 1);
    try expect(csv.cols == 1);
    try expect(eql(u8, csv.get(0, 0).?, "zero ,\n "));
    try expect(csv.get(1, 1) == null);
}
