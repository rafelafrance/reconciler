const std = @import("std");
const util = @import("../util/util.zig");

const indexOfAnyPos = std.mem.indexOfAnyPos;
const indexOfScalarPos = std.mem.indexOfScalarPos;

pub const Csv = struct {
    allocator: std.mem.Allocator,
    path: []const u8, // path to csv file
    delimiter: u8, // record delimiter
    cells: std.ArrayList(*Cell), // sparse list of parsed CSV cells
    enders: []u8, // characters that end a csv field
    table: []?[]u8 = undefined, // holds CSV strings, if cell is empty it is null
    curr_row: usize = 0, // current row when parsing
    curr_col: usize = 0, // current column when parsing
    rows: usize = 0, // total number of row CSV file
    cols: usize = 1, // maximum number of columns in a row (CSVs rows may be ragged)

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
        if (buff_size == 0) return;
        const size_m1 = buff_size - 1;
        var start: usize = 0;
        var end: usize = 0;

        while (start < buff_size) {
            if (raw[start] == self.delimiter) {
                if (start == 0 or Csv.is_eol(raw[start - 1])) {
                    self.next_col();
                    // try self.add(raw[start..start]);
                }
                while (start < size_m1 and raw[start + 1] == self.delimiter) {
                    self.next_col();
                    // try self.add(raw[start..start]);
                    start += 1; // Skip middle delimiter
                }
                if (start >= size_m1 or Csv.is_eol(raw[start + 1])) {
                    self.next_col();
                    start += 1; // Skip delimiter
                    // try self.add(raw[start..start]);
                    if (start < size_m1 and Csv.is_eol(raw[start])) start += 1;
                }
                start += 1; // Skip delimiter
            } else if (Csv.is_eol(raw[start])) {
                self.next_row();
                start += 1; // Skip EOL
                if (start < size_m1 and Csv.is_eol(raw[start])) start += 1; // Skip other EOL
            } else if (raw[start] == '"') {
                start += 1; // Skip starting quote
                end = indexOfScalarPos(u8, raw, start, '"').?;
                while (end < size_m1 and raw[end + 1] == '"') {
                    end = indexOfScalarPos(u8, raw, end + 2, '"').?;
                }
                try self.add(raw[start..end]);
                start = end + 1; // Skip ending quote
            } else {
                if (indexOfAnyPos(u8, raw, start, self.enders)) |e| {
                    end = e;
                    try self.add(raw[start..end]);
                    start = end;
                } else {
                    try self.add(raw[start..buff_size]);
                    break;
                }
            }
        }
        try self.createTable();
    }

    fn createTable(self: *Csv) !void {
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

    pub fn cell(self: Csv, row: usize, col: usize) ![]u8 {
        const idx = self.index(row, col);
        return @as([]u8, self.table[idx].?);
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
