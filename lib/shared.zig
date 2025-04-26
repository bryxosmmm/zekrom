const std = @import("std");
const mem = std.mem;
const io = std.io;
const fs = std.fs;

const print = std.debug.print;

const CREATE: []const u8 = "-- :create";
const DISTRUCT: []const u8 = "-- :drop";

pub const Command = enum {
    migrate,
    show_d,
    migrate_to,
    unknown,
    drop,
};

pub const Statements = struct {
    const Self = @This();
    version: usize,
    create_l: usize = 0,
    distruct_l: usize = 0,
    create: []u8,
    distruct: []u8,
    allocator: mem.Allocator,

    pub fn init(comptime max_size: usize, allocator: mem.Allocator, version: usize) !*Self {
        const self = try allocator.create(Self);
        const create_buf = try allocator.alloc(u8, max_size);
        const distruct_buf = try allocator.alloc(u8, max_size);
        self.* = .{ .create = create_buf, .distruct = distruct_buf, .allocator = allocator, .version = version };

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.create);
        self.allocator.free(self.distruct);

        self.allocator.destroy(self);
    }
};

pub fn get_version(s: []const u8) !?usize {
    var stream = io.fixedBufferStream(s);
    var reader = stream.reader();
    var buf: [16]u8 = undefined;
    const version = try reader.readUntilDelimiter(&buf, '_');
    const r = std.fmt.parseInt(u8, version, 10) catch {
        return null;
    };
    if (r == 0) {
        return null;
    }

    return r;
}

pub fn parse(allocator: mem.Allocator, reader: fs.File.Reader, statements: *Statements) !void {
    var stream_c = io.fixedBufferStream(statements.create);
    var writer_c = stream_c.writer();

    var stream_d = io.fixedBufferStream(statements.distruct);
    var writer_d = stream_d.writer();

    while (try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 256)) |line| {
        defer allocator.free(line);
        const trimmed_line = mem.trimRight(u8, line, "\r");

        if (mem.eql(u8, CREATE, trimmed_line)) {
            var buf: [512]u8 = undefined;
            const create_expr = try reader.readUntilDelimiter(&buf, ';');
            _ = try writer_c.write(create_expr);
            try writer_c.writeByte(';');
            statements.create_l = stream_c.pos;
        }
        if (mem.eql(u8, DISTRUCT, trimmed_line)) {
            var buf: [512]u8 = undefined;
            const create_expr = try reader.readUntilDelimiter(&buf, ';');
            _ = try writer_d.write(create_expr);
            try writer_d.writeByte(';');
            statements.distruct_l = stream_d.pos;
        }
    }
}

pub fn loadStatements(allocator: mem.Allocator, stash: *std.ArrayList(*Statements), dir: fs.Dir) !void {
    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (mem.eql(u8, fs.path.extension(entry.name), ".sql") and entry.kind == .file) {
            if (try get_version(entry.name)) |v| {
                print("INFO: Parsing file: {s}\n", .{entry.name});
                var file = try dir.openFile(entry.name, .{});
                defer file.close();

                const reader = file.reader();

                const statements = try Statements.init(1024, allocator, v);

                try parse(allocator, reader, statements);

                try stash.append(statements);
            }
        }
    }
}

pub fn sortStatements(_: void, a: *Statements, b: *Statements) bool {
    return a.version > b.version;
}
