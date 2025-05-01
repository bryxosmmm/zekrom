const std = @import("std");
const print = std.debug.print;
const exit = std.os.linux.exit;
const mem = std.mem;
const fs = std.fs;

const exec = @import("lib/exec.zig");
const shared = @import("lib/shared.zig");
const sql = @import("lib/sqlite3_bindings.zig");

fn read_version() usize {
    const version_str: [:0]const u8 = mem.span(std.os.argv[2]);
    const v = std.fmt.parseInt(usize, version_str, 10) catch {
        print("ERROR: provide the version", .{});
        exit(1);
    };
    return v;
}

pub fn main() !void {
    const command = std.meta.stringToEnum(shared.Command, std.mem.span(std.os.argv[1])) orelse .unknown;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    exec.setup_index() catch {
        exit(1);
    };
    switch (command) {
        .migrate_to => try exec.perform_migrate_to(allocator, dir, read_version()),
        .migrate => try exec.perform_migrate_latest(allocator, dir),
        .drop_to => _ = {
            try exec.drop_scripts(allocator);
            try exec.perform_migrate_to(allocator, dir, read_version());
        },
        else => exit(69),
    }
}
