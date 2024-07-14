const std = @import("std");
const util = @import("../util/util.zig");

const indexOfAnyPos = std.mem.indexOfAnyPos;
const indexOfScalarPos = std.mem.indexOfScalarPos;

pub const CsvReader = struct {
    allocator: std.mem.Allocator,
    path: []const u8,
    delimiter: u8,
    cells: std.ArrayList(*Cell),
    enders: []u8,

    pub fn init(config: struct {
        allocator: std.mem.Allocator,
        path: []const u8,
        comptime delimiter: u8 = ',',
    }) !CsvReader {
        const reader = CsvReader{
            .allocator = config.allocator,
            .path = config.path,
            .delimiter = config.delimiter,
            .cells = std.ArrayList(*Cell).init(config.allocator),
            .enders = try config.allocator.alloc(u8, 3),
        };
        reader.enders[0] = config.delimiter;
        reader.enders[1] = '\r';
        reader.enders[2] = '\n';
        return reader;
    }

    pub fn deinit(self: *CsvReader) void {
        self.allocator.free(self.enders);
        for (self.cells.items) |cell| {
            self.allocator.free(cell.buff);
            self.allocator.destroy(cell);
        }
        self.cells.deinit();
    }

    pub fn read(self: *CsvReader) !void {
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

    pub fn scan(self: *CsvReader, raw: []u8, size: usize) !void {
        if (size == 0) return;
        const size_m1 = size - 1;
        var start: usize = 0;
        var end: usize = 0;
        var grid = Grid{};

        while (start < size) {
            if (raw[start] == self.delimiter) {
                if (start == 0 or CsvReader.is_eol(raw[start - 1])) {
                    try self.add(grid, raw[start..start]);
                }
                while (start < size_m1 and raw[start + 1] == self.delimiter) {
                    grid.next_col();
                    try self.add(grid, raw[start..start]);
                    start += 1;
                }
                if (start >= size_m1 or CsvReader.is_eol(raw[start + 1])) {
                    grid.next_col();
                    try self.add(grid, raw[start..start]);
                    if (start < size_m1 and CsvReader.is_eol(raw[start])) start += 1;
                }
                grid.next_col();
                start += 1;
            } else if (CsvReader.is_eol(raw[start])) {
                grid.next_row();
                start += 1;
                if (start < size_m1 and CsvReader.is_eol(raw[start])) start += 1;
            } else if (raw[start] == '"') {
                start += 1; // Skip passed starting quote
                end = indexOfScalarPos(u8, raw, start, '"').?;
                while (end < size_m1 and raw[end + 1] == '"') {
                    end = indexOfScalarPos(u8, raw, end + 2, '"').?;
                }
                try self.add(grid, raw[start..end]);
                start = end + 1; // Skip passed ending quote
            } else {
                if (indexOfAnyPos(u8, raw, start, self.enders)) |e| {
                    end = e;
                    try self.add(grid, raw[start..end]);
                    start = end;
                } else {
                    try self.add(grid, raw[start..size]);
                    break;
                }
            }
        }
    }

    fn is_ender(self: CsvReader, char: u8) bool {
        for (self.enders) |e| {
            if (e == char) return true;
        }
        return false;
    }

    fn is_eol(char: u8) bool {
        return char == '\r' or char == '\n';
    }

    fn add(self: *CsvReader, grid: Grid, raw: []u8) !void {
        const ptr = try self.allocator.create(Cell);

        const buff = try self.allocator.alloc(u8, raw.len);
        const n = std.mem.replace(u8, raw, "\"\"", "\"", buff);
        const len = raw.len - n;

        ptr.* = Cell{ .row = grid.row, .col = grid.col, .buff = buff, .val = buff[0..len] };

        try self.cells.append(ptr);
    }

    const Grid = struct {
        row: i64 = 0,
        col: i64 = 0,

        fn next_row(self: *Grid) void {
            self.row += 1;
            self.col = 0;
        }

        fn next_col(self: *Grid) void {
            self.col += 1;
        }
    };
};

pub const Cell = struct {
    row: i64,
    col: i64,
    buff: []u8,
    val: []u8,
};
