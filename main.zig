const std = @import("std");
const print = std.debug.print;
const exit = std.os.linux.exit;
const mem = std.mem;
const fs = std.fs;

const exec = @import("lib/exec.zig");
const shared = @import("lib/shared.zig");
const sql = @import("lib/sqlite3_bindings.zig");

fn read_version() ?usize {
    if (std.os.argv.len < 3) {
        return null;
    }
    const version_str: [:0]const u8 = mem.span(std.os.argv[2]);
    const v = std.fmt.parseInt(usize, version_str, 10) catch {
        return null;
    };
    return v;
}

fn failwith(comptime s: []const u8, args: anytype) usize {
    print(s, args);
    exit(1);
    return 0;
}

fn proc_command(command: shared.Command, v: ?usize, dir: fs.Dir, allocator: mem.Allocator) !void {
    switch (command) {
        .migrate_to => {
            try exec.perform_migrate_to(allocator, dir, v orelse failwith("ERROR: missing version arg", .{}));
            try exec.write_to_index(allocator, "migrate_to", v orelse failwith("ERROR: missing version arg", .{}));
        },
        .migrate => {
            try exec.perform_migrate_latest(allocator, dir);
            try exec.write_to_index(allocator, "migrate", 0);
        },
        .drop_to => _ = {
            try exec.drop_scripts(allocator);
            try exec.perform_migrate_to(allocator, dir, v orelse failwith("ERROR: missing version arg", .{}));
            try exec.write_to_index(allocator, "drop_to", v orelse failwith("ERROR: missing version arg", .{}));
        },
        .drop => {
            const version = try exec.drop_by_one(allocator);
            try exec.perform_migrate_to(allocator, dir, version);
            try exec.write_to_index(allocator, "drop", 0);
        },
        .redo => {
            var index = exec.get_index(allocator) catch {
                print("ERROR: there is no last command", .{});
                exit(1);
            };
            defer index.deinit();
            try proc_command(index.command(), index.version, dir, allocator);
        },
        else => exit(69),
    }
}

pub fn main() !void {
    print("{s}", .{std.os.argv[1]});
    const command = std.meta.stringToEnum(shared.Command, std.mem.span(std.os.argv[1])) orelse .unknown;
    print("{}", .{command});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    exec.setup_index() catch {
        exit(1);
    };
    try proc_command(command, read_version(), dir, allocator);
}
