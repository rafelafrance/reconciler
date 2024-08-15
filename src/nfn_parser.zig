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

        if (nfn.csv.rows <= 1) {
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

            try self.parseAnnotations(annos);
            break;
        }
    }

    const Junk = struct {
        task: []u8 = "",
        value: []u8 = "",
        task_label: []u8 = "",
        label: []u8 = "",
        option: []u8 = "",
        select_label: []u8 = "",
    };

    fn prefix(scanner: std.json.Scanner, sub: u8) []const u8 {
        const leader = [_]u8{' '} ** 32;
        const indent: u32 = 2;
        return leader[0 .. indent * (scanner.stackHeight() - sub)];
    }

    fn parseAnnotations(self: NfnParser, annotations: []u8) !void {
        // const parsed = std.json.parseFromSlice(
        //     std.json.ArrayHashMap(Junk),
        //     self.allocator,
        //     annotations,
        //     .{},
        // ) catch |err| {
        //     print("error {!}\n", .{err});
        //     return err;
        // };
        // defer parsed.deinit();

        var scanner = std.json.Scanner.initCompleteInput(self.allocator, annotations);
        defer scanner.deinit();
        while (true) {
            switch (try scanner.peekNextTokenType()) {
                .end_of_document => break,
                .array_begin => {
                    _ = try scanner.next();
                    print("{s}[\n", .{NfnParser.prefix(scanner, 1)});
                },
                .array_end => {
                    _ = try scanner.next();
                    print("{s}]\n", .{NfnParser.prefix(scanner, 0)});
                },
                .object_begin => {
                    _ = try scanner.next();
                    print("{s}{{\n", .{NfnParser.prefix(scanner, 1)});
                },
                .object_end => {
                    _ = try scanner.next();
                    print("{s}}}\n", .{NfnParser.prefix(scanner, 0)});
                },
                .number => {
                    const token = try scanner.nextAlloc(self.allocator, .alloc_always);
                    print("{s}{s}\n", .{ NfnParser.prefix(scanner, 0), token.allocated_number });
                },
                .string => {
                    const token = try scanner.nextAlloc(self.allocator, .alloc_always);
                    print("{s}\"{s}\"\n", .{ NfnParser.prefix(scanner, 0), token.allocated_string });
                },
                .true => {
                    _ = try scanner.next();
                    print("{s}true\n", .{NfnParser.prefix(scanner, 0)});
                },
                .false => {
                    _ = try scanner.next();
                    print("{s}false\n", .{NfnParser.prefix(scanner, 0)});
                },
                .null => {
                    _ = try scanner.next();
                    print("{s}null\n", .{NfnParser.prefix(scanner, 0)});
                },
            }
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
