const std = @import("std");
const csv_parser = @import("csv_parser.zig");

const print = std.debug.print;
const eql = std.mem.eql;

pub const NfnParser = struct {
    allocator: std.mem.Allocator,
    csv: csv_parser.CsvParser = undefined,
    workflow_id: usize, // Column index for the workflow_id
    workflow_name: usize, // Column index for the workflow_name

    pub fn init(config: struct {
        allocator: std.mem.Allocator,
        csv_parser: csv_parser.CsvParser,
    }) !NfnParser {
        var nfn = NfnParser{
            .allocator = config.allocator,
            .csv = config.csv_parser,
            .workflow_id = undefined,
            .workflow_name = undefined,
        };

        if (nfn.csv.rows < 2) {
            std.log.err("The CSV file is missing data.\n", .{});
            return NfnError.NoData;
        }

        nfn.workflow_id = try nfn.get_workflow_id();
        nfn.workflow_name = nfn.csv.firstInRow(0, @constCast("workflow_name")).?;

        try nfn.parse();

        return nfn;
    }

    fn parse(self: *NfnParser) !void {
        const sub_id_col = self.csv.firstInRow(0, @constCast("subject_ids")).?;
        const class_id_col = self.csv.firstInRow(0, @constCast("classification_id")).?;
        const user_name_col = self.csv.firstInRow(0, @constCast("user_name")).?;
        const anno_col = self.csv.firstInRow(0, @constCast("annotations")).?;

        for (1..self.csv.rows) |i| {
            const sub_id = self.csv.table[i][sub_id_col].?;
            const class_id = self.csv.table[i][class_id_col].?;
            const user_name = self.csv.table[i][user_name_col].?;
            const annos = self.csv.table[i][anno_col].?;
            print("{} {s} {s} {s}\n", .{ i, sub_id, class_id, user_name });
            print("{s}\n\n", .{annos});
            var scanner = std.json.Scanner.initCompleteInput(self.allocator, annos);
            defer scanner.deinit();
            while (true) {
                switch (try scanner.peekNextTokenType()) {
                    .end_of_document => {
                        std.debug.print("EOD\n", .{});
                        break;
                    },
                    .array_begin => {
                        _ = try scanner.next();
                        std.debug.print("array begin\n", .{});
                    },
                    .array_end => {
                        _ = try scanner.next();
                        std.debug.print("array end\n", .{});
                    },
                    .object_begin => {
                        _ = try scanner.next();
                        std.debug.print("object begin\n", .{});
                    },
                    .object_end => {
                        _ = try scanner.next();
                        std.debug.print("object end\n", .{});
                    },
                    .number => {
                        _ = try scanner.next();
                        std.debug.print("number\n", .{});
                    },
                    .string => {
                        const token = try scanner.nextAlloc(self.allocator, .alloc_always);
                        std.debug.print("string '{s}'\n", .{token.allocated_string});
                    },
                    .true => {
                        _ = try scanner.next();
                        std.debug.print("true\n", .{});
                    },
                    .false => {
                        _ = try scanner.next();
                        std.debug.print("false\n", .{});
                    },
                    .null => {
                        _ = try scanner.next();
                        std.debug.print("null\n", .{});
                    },
                }
            }
            break;
        }
    }

    pub fn deinit() void {}

    fn get_workflow_id(self: NfnParser) !usize {
        const idx = self.csv.firstInRow(0, @constCast("workflow_id"));
        if (idx == null) {
            std.log.err("The CSV file is missing a 'workflow_id' column.\n", .{});
            return NfnError.WrongCsvType;
        }

        const col = idx.?;
        const workflow_id = self.csv.table[1][col].?;

        for (2..self.csv.rows) |row| {
            if (!eql(u8, self.csv.table[row][col].?, workflow_id)) {
                std.log.err("There are multiple workflow_ids in this CSV.", .{});
                return NfnError.MultipleWorkflows;
            }
        }
        return col;
    }
};

pub const NfnError =
    error{ NoData, WrongCsvType, MultipleWorkflows };
