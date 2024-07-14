const std = @import("std");

test {
    _ = @import("arg_parser/arg_parser_tests.zig");
    _ = @import("csv_reader/csv_reader_test.zig");
    _ = @import("util/util.zig");
}

test "my custom lib test" {
    try std.testing.expect(1 == 1);
}
