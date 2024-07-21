//! This is a minimal CSV parser library.
//! Input a string and parse it into rows and columns.
//! Output a grid/rectangle of optional slice pointers.
//! I try not to deviate from RFC 4180, and handle some weird stuff that I've seen.

const std = @import("std");

pub const Csv = struct {
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
    }) !Csv {
        return Csv{
            .allocator = config.allocator,
            .delimiter = config.delimiter,
            .raw_cells = std.ArrayList(*RawCell).init(config.allocator),
        };
    }

    pub fn deinit(self: *Csv) void {
        self.allocator.free(self.table);
        for (self.raw_cells.items) |item| {
            self.allocator.free(item.buff);
            self.allocator.destroy(item);
        }
        self.raw_cells.deinit();
    }

    pub inline fn index(self: Csv, row: usize, col: usize) usize {
        return row * self.cols + col;
    }

    pub inline fn inBounds(self: Csv, row: usize, col: usize) bool {
        return row < self.rows and col < self.cols;
    }

    /// Get the contents of a cell.
    pub fn get(self: Csv, row: usize, col: usize) ?[]u8 {
        if (!self.inBounds(row, col)) return null;
        return self.table[self.index(row, col)];
    }

    /// Find the first occurrence of the given string in a row and return its index.
    /// I use this to look for headers.
    pub fn firstInRow(self: Csv, row: usize, value: []u8) ?usize {
        for (0..self.cols) |col| {
            const cell_value = self.get(row, col) orelse continue;
            if (std.mem.eql(u8, cell_value, value)) return col;
        }
        return null;
    }

    // Convert a string into a CSV table.
    // A table is nothing more than a grid of optional string slices.
    pub fn parseString(self: *Csv, str: []u8) !void {
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
            } else if (Csv.isEol(str[pos])) {
                pos += 1; // skip eol
                if (pos < last_idx) {
                    if (Csv.isEol(str[pos]) and str[pos - 1] != str[pos]) pos += 1; // skip eol
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

    fn appendRawCell(self: *Csv, raw: []u8, coords: Coords, quoted: bool) !void {
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

    fn createTable(self: *Csv) !void {
        self.table = try self.allocator.alloc(?[]u8, self.rows * self.cols);
        for (self.table) |*cell| cell.* = null;
        for (self.raw_cells.items) |item| {
            self.table[self.index(item.row, item.col)] = item.val;
        }
    }

    fn clear(self: *Csv) void {
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

        fn nextRow(self: *Coords, csv: *Csv) void {
            self.row += 1;
            self.col = 0;
            csv.rows = self.row + 1;
        }

        fn nextCol(self: *Coords, csv: *Csv) void {
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

const CsvError = error{OutOfBounds};
