const std = @import("std");
const csv_ = @import("../csv/csv.zig");
const Csv = csv_.Csv;

const print = std.debug.print;

pub const Nfn = struct {
    allocator: std.mem.Allocator,
    csv: Csv = undefined,
    // workflow_id: []u8,
    // workflow_name: []u8,

    pub fn init(config: struct {
        allocator: std.mem.Allocator,
        csv: Csv,
    }) !Nfn {
        const nfn = Nfn{
            .allocator = config.allocator,
            .csv = config.csv,
        };
        try nfn.get_workflow_id();
        return nfn;
    }

    pub fn deinit() void {}

    fn get_workflow_id(self: Nfn) !void {
        print("csv shape [{},{}]\n", .{ self.csv.rows, self.csv.cols });
        for (0..self.csv.cols) |c| print("{s}\n", .{try self.csv.cellValue(0, c)});
        const col = self.csv.findInRow(0, @constCast("workflow_id")) catch null;
        if (col == null) {
            std.log.err("The CSV file is missing a 'workflow_id' column, it is not in Nfn format.", .{});
            return NfnError.WrongCsvType;
        }
        print("idx = {?}\n", .{col});
    }
};

pub const NfnError = error{ WrongCsvType, MultipleWorkflows };
