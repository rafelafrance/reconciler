const std = @import("std");
const csv_parser = @import("csv_parser.zig");

const print = std.debug.print;
const eql = std.mem.eql;

pub const NfnParser = struct {
    allocator: std.mem.Allocator,
    csv_parser: csv_parser.CsvParser = undefined,
    workflow_id: usize, // Column index for the workflow_id
    workflow_name: usize, // Column index for the workflow_name

    pub fn init(config: struct {
        allocator: std.mem.Allocator,
        csv_parser: csv_parser.CsvParser,
    }) !NfnParser {
        var nfn = NfnParser{
            .allocator = config.allocator,
            .csv_parser = config.csv_parser,
            .workflow_id = undefined,
            .workflow_name = undefined,
        };

        if (nfn.csv_parser.rows < 2) {
            std.log.err("The CSV file is missing data.\n", .{});
            return NfnError.NoData;
        }

        nfn.workflow_id = try nfn.get_workflow_id();
        nfn.workflow_name = nfn.csv_parser.firstInRow(0, @constCast("workflow_name")).?;
        return nfn;
    }

    pub fn deinit() void {}

    fn get_workflow_id(self: NfnParser) !usize {
        const idx = self.csv_parser.firstInRow(0, @constCast("workflow_id"));
        if (idx == null) {
            std.log.err("The CSV file is missing a 'workflow_id' column, it is not in Nfn format.\n", .{});
            return NfnError.WrongCsvType;
        }

        const col = idx.?;
        const workflow_id = self.csv_parser.get(1, col).?;

        for (2..self.csv_parser.rows) |row| {
            if (!eql(u8, self.csv_parser.get(row, col).?, workflow_id)) {
                std.log.err("There are multiple workflow_ids in this CSV.", .{});
                return NfnError.MultipleWorkflows;
            }
        }
        return col;
    }
};

pub const NfnError = error{ NoData, WrongCsvType, MultipleWorkflows };
