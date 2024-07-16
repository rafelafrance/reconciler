const std = @import("std");
const util = @import("../util/util.zig");

const indexOfAnyPos = std.mem.indexOfAnyPos;
const indexOfScalarPos = std.mem.indexOfScalarPos;
const print = std.debug.print;

pub const Csv = struct {
    allocator: std.mem.Allocator,
    path: []const u8, // path to csv file
    delimiter: u8, // record delimiter
    cells: std.ArrayList(*Cell), // sparse list of parsed CSV cells
    enders: []u8, // characters that end a csv field
    table: []?[]u8 = undefined, // holds CSV string pointers
    curr_row: usize = 0, // current row when parsing
    curr_col: usize = 0, // current column when parsing
    rows: usize = 1, // total number of rows in CSV file
    cols: usize = 0, // maximum number of columns in a row (CSVs rows may be ragged)

    pub fn init(config: struct {
        allocator: std.mem.Allocator,
        path: []const u8,
        delimiter: u8 = ',',
    }) !Csv {
        const csv = Csv{
            .allocator = config.allocator,
            .path = config.path,
            .delimiter = config.delimiter,
            .cells = std.ArrayList(*Cell).init(config.allocator),
            .enders = try config.allocator.alloc(u8, 3),
        };
        csv.enders[0] = config.delimiter;
        csv.enders[1] = '\r';
        csv.enders[2] = '\n';
        return csv;
    }

    pub fn deinit(self: *Csv) void {
        self.allocator.free(self.enders);
        self.allocator.free(self.table);
        for (self.cells.items) |item| {
            self.allocator.free(item.buff);
            self.allocator.destroy(item);
        }
        self.cells.deinit();
    }

    pub fn read(self: *Csv) !void {
        var file = try util.openfile(self.path);
        defer file.close();

        const stat = try file.stat();
        if (stat.size < 1) return;

        const raw = try std.posix.mmap(
            null,
            stat.size,
            std.posix.PROT.READ,
            .{ .TYPE = .SHARED },
            file.handle,
            0,
        );
        defer std.posix.munmap(raw);

        try self.scan(raw, stat.size);
    }

    pub fn scan(self: *Csv, raw: []u8, buff_size: usize) !void {
        if (buff_size > 0) {
            try self.parse(raw, buff_size);
        }
        try self.createTable();
    }

    fn parse(self: *Csv, raw: []u8, buff_size: usize) !void {
        const size_m1 = buff_size - 1;
        var pos: usize = 0;

        while (pos < buff_size) {
            if (raw[pos] == self.delimiter) {
                // Line starts with a comma, back fill a comma
                if (pos == 0 or Csv.is_eol(raw[pos - 1])) {}
                // Comma is followed by another comma, add columns for it
                while (pos < size_m1 and raw[pos + 1] == self.delimiter) {
                    self.next_col();
                    pos += 1;
                }
                // Line ends with a comma, add a final comma
                if (pos >= size_m1 or Csv.is_eol(raw[pos + 1])) {
                    self.next_col();
                    pos += 1;
                } else {
                    // Skip the current comma
                    self.next_col();
                    pos += 1;
                }
            } else if (Csv.is_eol(raw[pos])) {
                // Skip passed the EOL
                pos += 1;
                if (pos < size_m1 and Csv.is_eol(raw[pos])) pos += 1;
                if (pos < size_m1) self.next_row();
            } else if (raw[pos] == '"') {
                // Handle a quoted field
                pos += 1; // Skip starting quote
                var end = indexOfScalarPos(u8, raw, pos, '"').?;
                while (end < size_m1 and raw[end + 1] == '"') {
                    end = indexOfScalarPos(u8, raw, end + 2, '"').?;
                }
                try self.add(raw[pos..end]);
                pos = end + 1; // Skip ending quote
            } else {
                // Handle a normal field, find the next field ending character
                if (indexOfAnyPos(u8, raw, pos, self.enders)) |end| {
                    try self.add(raw[pos..end]);
                    pos = end;
                } else {
                    // Handle an EOF w/o a ending cr/lf
                    try self.add(raw[pos..buff_size]);
                    break;
                }
            }
        }
    }

    pub fn cell(self: Csv, row: usize, col: usize) ![]u8 {
        if (row >= self.rows or col >= self.cols) {
            const msg = "{!} max coordinates [{},{}] your coordinates [{},{}]\n";
            std.log.err(msg, .{ CsvError.OutOfBounds, self.rows - 1, self.cols - 1, row, col });
            return CsvError.OutOfBounds;
        }
        const idx = self.index(row, col);
        return self.table[idx] orelse "";
    }

    fn createTable(self: *Csv) !void {
        self.cols_fixup();
        self.table = try self.allocator.alloc(?[]u8, self.table_size());
        for (0..self.table.len) |i| self.table[i] = null;
        for (self.cells.items) |item| {
            self.table[self.index(item.row, item.col)] = item.val;
        }
    }

    fn is_ender(self: Csv, char: u8) bool {
        for (self.enders) |e| if (e == char) return true;
        return false;
    }

    fn is_eol(char: u8) bool {
        return char == '\r' or char == '\n';
    }

    fn add(self: *Csv, raw: []u8) !void {
        const ptr = try self.allocator.create(Cell);

        const buff = try self.allocator.alloc(u8, raw.len);
        const n = std.mem.replace(u8, raw, "\"\"", "\"", buff);
        const len = raw.len - n;

        ptr.* = Cell{
            .row = self.curr_row,
            .col = self.curr_col,
            .buff = buff,
            .val = buff[0..len],
        };

        try self.cells.append(ptr);
    }

    fn next_row(self: *Csv) void {
        self.curr_row += 1;
        self.curr_col = 0;
        self.rows = self.curr_row + 1;
    }

    fn next_col(self: *Csv) void {
        self.curr_col += 1;
        const col = self.curr_col + 1;
        if (col > self.cols) self.cols = col;
    }

    fn cols_fixup(self: *Csv) void {
        if (self.rows > 0 and self.cols == 0) self.cols = 1;
    }

    fn table_size(self: Csv) usize {
        return self.rows * self.cols;
    }

    fn index(self: Csv, row: usize, col: usize) usize {
        return row * self.cols + col;
    }

    const Cell = struct {
        row: usize,
        col: usize,
        buff: []u8,
        val: []u8,
    };
};

const CsvError = error{OutOfBounds};
