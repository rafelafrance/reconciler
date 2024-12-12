const std = @import("std");
const csv_parser = @import("csv_parser.zig");
const nfn_fields = @import("nfn_fields.zig");

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
            try self.flattenTasks(task, "");
        }
    }

    fn lt(_: void, lhs: std.json.Value, rhs: std.json.Value) bool {
        return std.mem.lessThan(u8, lhs.string, rhs.string);
    }

    fn jsonStringJoin(self: NfnParser, value: std.json.Value) ![]const u8 {
        var array = std.ArrayList([]const u8).init(self.allocator);
        for (value.array.items) |item| try array.append(item.string);
        const owned = try array.toOwnedSlice();
        const joined = std.mem.join(self.allocator, " ", owned);
        return joined;
    }

    fn flattenTasks(self: NfnParser, task: std.json.Value, prev_task_id: []const u8) JsonError!void {
        const task_obj = task.object;

        const task_id = if (task_obj.contains("task")) task_obj.get("task").?.string else prev_task_id;

        const value = task_obj.get("value").?;
        const first = if (eql(u8, @tagName(value), "array")) @tagName(value.array.items[0]) else "";

        if (eql(u8, first, "string")) {
            try self.listTask(task, task_id);
        } else if (eql(u8, first, "object") and value.array.items[0].object.contains("points")) {
            print("{s} polygon task\n", .{task_id});
        } else if (eql(u8, first, "array") and value.object.contains("highlighter")) {
            print("{s} highlighter task\n", .{task_id});
        } else if (eql(u8, first, "object")) {
            try self.subtasks(value, task_id);
        } else if (task_obj.contains("select_label")) {
            try self.selectLabelTask(task, task_id);
        } else if (task_obj.contains("task_label")) {
            try self.taskLabelTask(task, task_id);
        } else if (task_obj.contains("tool_label") and task_obj.contains("width")) {
            print("{s} {s}\n", .{ task_id, task_obj.get("tool_label").?.string });
        } else if (task_obj.contains("tool_label") and task_obj.contains("x1")) {
            print("{s} {s}\n", .{ task_id, task_obj.get("tool_label").?.string });
        } else if (task_obj.contains("markIndex")) {
            print("{s} {s}\n", .{ task_id, task_obj.get("markIndex").?.string });
        } else if (task_obj.contains("toolType") and eql(u8, task_obj.get("toolType").?.string, "point")) {
            print("{s} {s}\n", .{ task_id, task_obj.get("point").?.string });
        } else if (task_obj.contains("x") and task_obj.contains("y")) {
            print("{s} {s}\n", .{ task_id, task_obj.get("point").?.string });
        } else if (task_obj.contains("task_type") and eql(u8, task_obj.get("task_type").?.string, "dropdown-simple")) {
            print("{s} {s}\n", .{ task_id, task_obj.get("highlighter").?.string });
        } else {
            return JsonError.BadJson;
        }
    }

    fn subtasks(self: NfnParser, task: std.json.Value, task_id: []const u8) JsonError!void {
        for (task.array.items) |subtask| try self.flattenTasks(subtask, task_id);
    }

    fn listTask(self: NfnParser, task: std.json.Value, task_id: []const u8) !void {
        const value = task.object.get("value").?;
        std.mem.sort(std.json.Value, value.array.items, {}, lt);
        const joined = try self.jsonStringJoin(value);
        const name = task.object.get("task_label").?.string;
        const field = try nfn_fields.TextField.init(name, task_id, joined);
        print("{s} {s} = {s}\n", .{ field.task_id, field.name, field.value });
    }

    fn selectLabelTask(_: NfnParser, task: std.json.Value, task_id: []const u8) !void {
        var value: []const u8 = "";
        if (task.object.contains("option")) {
            value = task.object.get("label").?.string;
        } else {
            value = task.object.get("value").?.string;
        }
        const name = task.object.get("select_label").?.string;
        const field = try nfn_fields.SelectField.init(name, task_id, value);
        print("{s} {s} = {s}\n", .{ field.task_id, field.name, field.value });
    }

    fn taskLabelTask(_: NfnParser, task: std.json.Value, task_id: []const u8) !void {
        const value: []const u8 = task.object.get("value").?.string;
        const name = task.object.get("task_label").?.string;
        const field = try nfn_fields.TextField.init(name, task_id, value);
        print("{s} {s} = {s}\n", .{ field.task_id, field.name, field.value });
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
    error{ NoData, WrongCsvType, MultipleWorkflows, BadJson, OutOfMemory };
