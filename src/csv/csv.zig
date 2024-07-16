const std = @import("std");

pub const Csv = struct {
    allocator: std.mem.Allocator,
    delimiter: u8, // record delimiter
    cells: std.ArrayList(*Cell), // sparse list of parsed CSV cells
    table: []?[]u8 = undefined, // holds CSV string pointers
    rows: usize = 1, // total number of rows in CSV file AFTER parsing
    cols: usize = 0, // maximum number of columns in a row (CSVs rows may be ragged)
    curr_row: usize = 0, // current row when parsing
    curr_col: usize = 0, // current column when parsing

    pub fn init(config: struct {
        allocator: std.mem.Allocator,
        delimiter: u8 = ',',
    }) !Csv {
        return Csv{
            .allocator = config.allocator,
            .delimiter = config.delimiter,
            .cells = std.ArrayList(*Cell).init(config.allocator),
        };
    }

    pub fn deinit(self: *Csv) void { // skip if using an arena
        self.allocator.free(self.table);
        for (self.cells.items) |item| {
            self.allocator.free(item.buff);
            self.allocator.destroy(item);
        }
        self.cells.deinit();
    }

    pub fn cellValue(self: Csv, row: usize, col: usize) ![]u8 {
        if (row >= self.rows or col >= self.cols) {
            const msg = "{!} max coordinates [{},{}] your coordinates [{},{}]\n";
            std.log.err(msg, .{ CsvError.OutOfBounds, self.rows - 1, self.cols - 1, row, col });
            return CsvError.OutOfBounds;
        }
        const idx = row * self.cols + col;
        return self.table[idx] orelse "";
    }

    pub fn findInRow(self: Csv, row: usize, value: []u8) !?usize {
        for (0..self.cols) |col| {
            const contents = try self.cellValue(row, col);
            if (std.mem.eql(u8, contents, value)) return col;
        }
        return null;
    }

    pub fn parseString(self: *Csv, str: []u8) !void {
        if (str.len > 0) {
            try self.stringParser(str);
        }
        try self.createTable();
    }

    fn stringParser(self: *Csv, str: []u8) !void {
        const size_m1 = str.len - 1;
        const array = [_]u8{ self.delimiter, '\r', '\n' };
        const enders = array[0..]; // Chars that end a cell
        var pos: usize = 0;

        while (pos < str.len) {
            if (str[pos] == self.delimiter) {
                pos += 1; // skip delimiter
                self.nextCol();
            } else if (Csv.isEol(str[pos])) {
                pos += 1; // skip eol
                if (pos < size_m1 and Csv.isEol(str[pos])) pos += 1; // skip eol
                if (pos < size_m1) self.nextRow();
            } else if (str[pos] == '"') {
                pos += 1; // skip starting quote
                var end = std.mem.indexOfScalarPos(u8, str, pos, '"').?;
                while (end < size_m1 and str[end + 1] == '"') {
                    end = std.mem.indexOfScalarPos(u8, str, end + 2, '"').?;
                }
                try self.appendCell(str[pos..end]);
                pos = end + 1; // skip ending quote
            } else {
                if (std.mem.indexOfAnyPos(u8, str, pos, enders)) |end| {
                    try self.appendCell(str[pos..end]);
                    pos = end;
                } else {
                    try self.appendCell(str[pos..str.len]);
                    pos = str.len;
                }
            }
        }
    }

    fn appendCell(self: *Csv, raw: []u8) !void {
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

    fn createTable(self: *Csv) !void {
        if (self.rows > 0 and self.cols == 0) self.cols = 1; // Fix up single column CSVs
        self.table = try self.allocator.alloc(?[]u8, self.rows * self.cols);
        for (0..self.table.len) |i| self.table[i] = null;
        for (self.cells.items) |item| {
            const idx = item.row * self.cols + item.col;
            self.table[idx] = item.val;
        }
    }

    inline fn isEol(char: u8) bool {
        return char == '\r' or char == '\n';
    }

    fn nextRow(self: *Csv) void {
        self.curr_row += 1;
        self.curr_col = 0;
        self.rows = self.curr_row + 1;
    }

    fn nextCol(self: *Csv) void {
        self.curr_col += 1;
        const col = self.curr_col + 1;
        if (col > self.cols) self.cols = col;
    }

    const Cell = struct {
        row: usize,
        col: usize,
        buff: []u8,
        val: []u8,
    };
};

const CsvError = error{ OutOfBounds, NoFile };
