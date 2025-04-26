const std = @import("std");
const print = std.debug.print;
const exit = std.os.linux.exit;
const mem = std.mem;
const fs = std.fs;

const exec = @import("lib/exec.zig");
const shared = @import("lib/shared.zig");

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
        .migrate_to => try exec.perform(.migrate_to, allocator, dir, 2),
        .drop => try exec.perform(.drop, allocator, dir, 2),
        .migrate => try exec.perform_migrate_latest(allocator, dir),
        .show_d => try exec.get_scripts(),
        else => exit(69),
    }
}
