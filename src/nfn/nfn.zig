const std = @import("std");
const csv_ = @import("../csv/csv.zig");
const Csv = csv_.Csv;

const print = std.debug.print;
const eql = std.mem.eql;

pub const Nfn = struct {
    allocator: std.mem.Allocator,
    csv: Csv = undefined,
    workflow_id: usize, // Column index for the workflow_id
    workflow_name: usize, // Column index for the workflow_name

    pub fn init(config: struct {
        allocator: std.mem.Allocator,
        csv: Csv,
    }) !Nfn {
        var nfn = Nfn{
            .allocator = config.allocator,
            .csv = config.csv,
            .workflow_id = undefined,
            .workflow_name = undefined,
        };

        if (nfn.csv.rows < 2) {
            std.log.err("The CSV file is missing data.\n", .{});
            return NfnError.NoData;
        }

        nfn.workflow_id = try nfn.get_workflow_id();
        nfn.workflow_name = (try nfn.csv.firstInRow(0, @constCast("workflow_name"))).?;
        return nfn;
    }

    pub fn deinit() void {}

    fn get_workflow_id(self: Nfn) !usize {
        const idx = self.csv.firstInRow(0, @constCast("workflow_id")) catch null;
        if (idx == null) {
            std.log.err("The CSV file is missing a 'workflow_id' column, it is not in Nfn format.\n", .{});
            return NfnError.WrongCsvType;
        }

        const col = idx.?;
        const workflow_id = try self.csv.cellValue(1, col);

        for (2..self.csv.rows) |row| {
            if (!eql(u8, (try self.csv.cellValue(row, col)).?, workflow_id.?)) {
                std.log.err("There are multiple workflow_ids in this CSV.", .{});
                return NfnError.MultipleWorkflows;
            }
        }
        return col;
    }
};

pub const NfnError = error{ NoData, WrongCsvType, MultipleWorkflows };
