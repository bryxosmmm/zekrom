const std = @import("std");
const sql = @cImport({
    @cInclude("sqlite3.h");
});

const OK = sql.SQLITE_OK;
pub const TRANSIENT = sql.SQLITE_TRANSIENT;
pub const DONE = sql.SQLITE_DONE;

pub const raw_step = sql.sqlite3_step;

pub const sqlite3 = ?*sql.sqlite3;
pub const sql_stmt = ?*sql.sqlite3_stmt;
pub const c_string = [*:0]const u8;

pub const Text = struct {
    content_ptr: [:0]const u8,
    length: c_int,
    allocator: std.mem.Allocator,
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, c: []u8, length: usize) !Self {
        const sql_str = try std.fmt.allocPrintZ(allocator, "{s}", .{c[0..length]});
        return Text{ .content_ptr = sql_str, .length = @intCast(length), .allocator = allocator };
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.content_ptr);
        // self.allocator.destroy(self);
    }
};

pub fn init(f: c_string) !sqlite3 {
    var db: sqlite3 = null;

    const rc = sql.sqlite3_open(f, &db);
    if (rc != sql.SQLITE_OK) {
        std.debug.print("ERROR: Failed to open DB: {s}\n", .{sql.sqlite3_errmsg(db)});
        return error.Open;
    }
    return db;
}

pub fn deinit(conn: sqlite3) !void {
    const rc = sql.sqlite3_close(conn);
    if (rc != sql.SQLITE_OK) {
        std.debug.print("ERROR: Failed to close conn: {s}\n", .{sql.sqlite3_errmsg(conn)});
        return error.Close;
    }
}

pub fn proc_error(comptime s: []const u8, db: sqlite3, rc: c_int) !void {
    if (rc != OK) {
        std.debug.print(s, .{sql.sqlite3_errmsg(db)});
        return error.NotOk;
    }
}

pub fn exec(db: sqlite3, s: c_string) !void {
    const rc = sql.sqlite3_exec(db, s, null, null, null);
    proc_error("ERROR: failed to exec: {s}\n", db, rc) catch {
        return error.Exec;
    };
}
pub fn prepare(db: sqlite3, comptime sql_string: [*c]const u8) !sql_stmt {
    var stmt: ?*sql.sqlite3_stmt = null;
    const rc = sql.sqlite3_prepare_v2(db, sql_string, -1, &stmt, null);
    proc_error("ERROR: failed to prepare query: {s}", db, rc) catch {
        return error.Prepare;
    };
    return stmt;
}

pub fn bind_text(db: sqlite3, comptime pos: c_uint, stmt: sql_stmt, text: Text, comptime flag: anytype) !void {
    const rc = sql.sqlite3_bind_text(stmt, pos, text.content_ptr, text.length, flag);
    proc_error("ERROR: failed to bind text: {s}\n", db, rc) catch {
        return error.BindText;
    };
}

pub fn bind_int(db: sqlite3, stmt: sql_stmt, comptime pos: c_int, v: c_int) !void {
    const rc = sql.sqlite3_bind_int(stmt, pos, v);
    proc_error("ERROR: failed to bind int: {s}\n", db, rc) catch {
        return error.BindInt;
    };
}

pub fn step(db: sqlite3, stmt: sql_stmt) !void {
    const rc = raw_step(stmt);
    if (rc != DONE) {
        std.debug.print("ERROR: failed to step the staitment: {s}", .{sql.sqlite3_errmsg(db)});
        return error.Step;
    }
}

pub fn finalize(db: sqlite3, stmt: sql_stmt) !void {
    const rc = sql.sqlite3_finalize(stmt);
    if (rc != sql.SQLITE_OK) {
        std.debug.print("ERROR: failed to finalize the staitment: {s}", .{sql.sqlite3_errmsg(db)});
        return error.Finalize;
    }
}

pub fn column_text(comptime pos: c_int, stmt: sql_stmt) ![:0]const u8 {
    const ptr: [*c]const u8 = sql.sqlite3_column_text(stmt, pos) orelse {
        std.debug.print("ERROR: text is NULL", .{});
        return error.ColumnText;
    };
    return std.mem.span(ptr);
}

pub fn column_int(comptime pos: c_int, stmt: sql_stmt) isize {
    const i = sql.sqlite3_column_int(stmt, pos);
    return i;
}
