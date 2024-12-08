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
            return JsonError.NoData;
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

    fn parseAnnotations(self: NfnParser, annotations: []u8) !void {
        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, annotations, .{});
        defer parsed.deinit();

        const root = parsed.value;

        for (root.array.items) |task| {
            try self.flatten_tasks(task, "");
        }
    }

    fn flatten_tasks(self: NfnParser, task_value: std.json.Value, prev_task_id: []const u8) !void {
        const task = task_value.object;

        const task_id = if (task.contains("task")) task.get("task").?.string else prev_task_id;

        const value = task.get("value").?;
        const first = if (eql(u8, @tagName(value), "array")) @tagName(value.array.items[0]) else "";

        if (eql(u8, first, "string")) {
            print("{s} list task\n", .{task_id});
            // std.mem.dupe...
            // std.mem.sort([]u8, &value.array.items, {}, std.sort.asc([]u8));
            // const joined = try std.mem.join(self.allocator, " ", value.array.items);
            // print("{s}\n", .{joined});
        } else if (eql(u8, first, "object") and value.array.items[0].object.contains("points")) {
            print("{s} polygon task\n", .{task_id});
        } else if (eql(u8, first, "array") and value.object.contains("highlighter")) {
            print("{s} highlighter task\n", .{task_id});
        } else if (eql(u8, first, "object")) {
            for (value.array.items) |subtask| {
                try self.flatten_tasks(subtask, task_id);
            }
        } else if (task.contains("select_label")) {
            print("{s} {s}\n", .{ task_id, task.get("select_label").?.string });
        } else if (task.contains("task_label")) {
            print("{s} {s}\n", .{ task_id, task.get("task_label").?.string });
        } else if (task.contains("tool_label") and task.contains("width")) {
            print("{s} {s}\n", .{ task_id, task.get("tool_label").?.string });
        } else if (task.contains("tool_label") and task.contains("x1")) {
            print("{s} {s}\n", .{ task_id, task.get("tool_label").?.string });
        } else if (task.contains("markIndex")) {
            print("{s} {s}\n", .{ task_id, task.get("markIndex").?.string });
        } else if (task.contains("toolType") and eql(u8, task.get("toolType").?.string, "point")) {
            print("{s} {s}\n", .{ task_id, task.get("point").?.string });
        } else if (task.contains("x") and task.contains("y")) {
            print("{s} {s}\n", .{ task_id, task.get("point").?.string });
        } else if (task.contains("task_type") and eql(u8, task.get("task_type").?.string, "dropdown-simple")) {
            print("{s} {s}\n", .{ task_id, task.get("highlighter").?.string });
        } else {
            return JsonError.BadJson;
        }
    }

    pub fn deinit() void {}

    fn get_workflow_id(self: NfnParser) !usize {
        const idx = self.csv.firstInRow(0, @constCast("workflow_id"));
        if (idx == null) {
            std.log.err("The CSV file is missing a 'workflow_id' column.\n", .{});
            return JsonError.WrongCsvType;
        }

        const col = idx.?;
        const workflow_id = self.csv.table[1][col].?;

        for (2..self.csv.rows) |row| {
            if (!eql(u8, self.csv.table[row][col].?, workflow_id)) {
                std.log.err("There are multiple workflow_ids in this CSV.", .{});
                return JsonError.MultipleWorkflows;
            }
        }
        return col;
    }
};

pub const JsonError =
    error{ NoData, WrongCsvType, MultipleWorkflows, BadJson };
