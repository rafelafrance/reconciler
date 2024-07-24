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
            print("{s}\n", .{annos});
            var scanner = std.json.Scanner.initCompleteInput(self.allocator, annos);
            defer scanner.deinit();
            var diag = std.json.Diagnostics{};
            scanner.enableDiagnostics(&diag);
            while (true) {
                switch (try scanner.peekNextTokenType()) {
                    .end_of_document => break,
                    .array_begin => {
                        std.debug.print("Array began\n", .{});
                        _ = try scanner.next(); // skip
                    },
                    .array_end => {
                        std.debug.print("Array end\n", .{});
                        _ = try scanner.next(); // skip
                    },
                    .string => switch (try scanner.next()) {
                        .string, .partial_string => |payload| {
                            std.debug.print("String found: `{s}` (line: {}, col: {})\n", .{ payload, diag.getLine(), diag.getColumn() });
                        },
                        else => return error.UnexpectedToken,
                    },
                    .object_begin => {
                        _ = try scanner.next(); // skip object begin token
                        const key = (try scanner.next()).string;
                        const value = switch (try scanner.next()) {
                            .string, .partial_string => |payload| payload,
                            else => return error.NotCoveredToken,
                        };
                        _ = try scanner.next(); // skip object end token

                        std.debug.print("Object pair found: key:`{s}`, value:`{s}` (line: {}, col: {})\n", .{ key, value, diag.getLine(), diag.getColumn() });
                    },
                    .object_end => {
                        std.debug.print("Object end\n", .{});
                        _ = try scanner.next(); // skip
                    },
                    else => return error.NotCoveredToken,
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
