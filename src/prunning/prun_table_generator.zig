const std = @import("std");
const prunning = @import("prunning");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const sizes = [_]usize { 263_000, 32_000, 11_650_000 };

    for (0..3) |i| {
        const cache_file_path = args[i + 1];
        const cache_file = try std.fs.cwd().createFile(cache_file_path, .{});
        defer cache_file.close();

        const file_name = cache_file_path[std.mem.lastIndexOf(u8, cache_file_path, "/").? + 1..];
        const file_path = try std.fs.path.join(allocator, &[_][]const u8 {"src/prunning", file_name});
        defer allocator.free(file_path);
        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();

        const buffer = try allocator.alloc(u8, sizes[i]);
        defer allocator.free(buffer);

        const string_table = switch (i) {
            0 => try std.fmt.bufPrint(buffer,
                "pub const corner_perm_prun_table = [45360]u16 {any};",
                .{prunning.create_corner_perm_prun_table()}
            ),
            1 => try std.fmt.bufPrint(buffer,
                "pub const corner_twist_prun_table = [6561]u16 {any};",
                .{prunning.create_corner_twist_prun_table()}
            ),
            2 => try std.fmt.bufPrint(buffer,
                "pub const corner_depth = [3674160]u8 {any};",
                .{prunning.create_depth_prun_table()}
            ),
            else => unreachable,
        };

        try writeBreak(cache_file, string_table, 125);
        try writeBreak(file, string_table, 125);
    }
}

fn writeBreak(file: std.fs.File, string: []const u8, line_length: usize) !void {
    var buffered = std.io.bufferedWriter(file.writer());
    const writer = buffered.writer();

    var i: usize = 0;
    while (i < string.len) {
        const end = @min(i + line_length, string.len);

        const last_comma_idx = std.mem.lastIndexOf(u8, string[i..end], ",");

        if (last_comma_idx != null and end < string.len) {
            try writer.writeAll(string[i..i + last_comma_idx.? + 1]);
            i += last_comma_idx.? + 1;
        } else {
            try writer.writeAll(string[i..end]);
            i = end;
        }

        try writer.writeByte('\n');
    }

    try buffered.flush();
}