const std = @import("std");

pub fn openfile(path: []const u8) !std.fs.File {
    var file: std.fs.File = undefined;
    if (std.fs.path.isAbsolute(path)) {
        file = std.fs.openFileAbsolute(path, .{}) catch |err| {
            std.log.err("{!} when opening '{s}'.", .{ err, path });
            return err;
        };
    } else {
        file = std.fs.cwd().openFile(path, .{}) catch |err| {
            std.log.err("{!} when opening '{s}'.", .{ err, path });
            return err;
        };
    }
    return file;
}
