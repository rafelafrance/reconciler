const std = @import("std");

test {
    _ = @import("args/arg_tests.zig");
    _ = @import("csv/csv_test.zig");
    _ = @import("nfn/nfn_test.zig");
    _ = @import("util/util_test.zig");
}
