const std = @import("std");
const print = std.debug.print;
const exit = std.os.linux.exit;
const io = std.io;
const mem = std.mem;
const fs = std.fs;

const sql = @import("sqlite3_bindings.zig");

const shared = @import("shared.zig");
const Statements = shared.Statements;
const Command = shared.Command;

pub fn migrate_table(conn: sql.sqlite3, allocator: mem.Allocator, table_stmt: *Statements) !void {
    print("DEBUG: create_expr: {s}\n", .{table_stmt.create});
    print("DEBUG: version: {}\n", .{table_stmt.version});
    const sql_str = try std.fmt.allocPrintZ(allocator, "{s}", .{table_stmt.create[0..table_stmt.create_l]});
    defer allocator.free(sql_str);
    try sql.exec(conn, sql_str);
}

pub fn drop_table(conn: sql.sqlite3, allocator: mem.Allocator, table_stmt: *Statements) !void {
    print("DEBUG: distruct_expr: {s}\n", .{table_stmt.distruct});
    print("DEBUG: version: {}\n", .{table_stmt.version});
    const sql_str = try std.fmt.allocPrintZ(allocator, "{s}", .{table_stmt.distruct[0..table_stmt.distruct_l]});
    defer allocator.free(sql_str);
    try sql.exec(conn, sql_str);
}

pub fn perform_migrate_to(allocator: mem.Allocator, dir: fs.Dir, version: usize) !void {
    const db = try sql.init("data.db");
    defer sql.deinit(db) catch {
        exit(1);
    };

    var stash = std.ArrayList(*Statements).init(allocator);
    defer {
        for (stash.items) |i| {
            i.deinit();
        }
        stash.deinit();
    }

    try shared.loadStatements(allocator, &stash, dir);

    for (stash.items) |i| {
        if (i.version == version) {
            migrate_table(db, allocator, i) catch {
                exit(1);
            };
            add_to_scripts(allocator, db, i) catch {
                print("WARN: can not write to the scirpts while migrating\n", .{});
            };
        }
    }
}

pub fn perform_migrate_latest(allocator: mem.Allocator, dir: fs.Dir) !void {
    const db = try sql.init("data.db");
    defer sql.deinit(db) catch {
        exit(1);
    };

    var stash = std.ArrayList(*Statements).init(allocator);
    defer stash.deinit();
    try shared.loadStatements(allocator, &stash, dir);
    const items = try stash.toOwnedSlice();
    defer {
        for (items) |i| {
            i.deinit();
        }
        allocator.free(items);
    }

    std.mem.sort(*Statements, items, {}, shared.sortStatements);
    var latest: usize = 0;
    for (items) |i| {
        if (latest == 0) {
            latest = i.version;
        }
        if (i.version == latest) {
            migrate_table(db, allocator, i) catch {
                exit(1);
            };
            add_to_scripts(allocator, db, i) catch {
                print("WARN: cant load stmt to index\n", .{});
            };
        }
    }
}

pub fn setup_index() !void {
    const db = try sql.init("data.db");
    defer sql.deinit(db) catch {
        exit(1);
    };

    try sql.exec(db, "create table if not exists migration_index(migration_id int not null);");
    try sql.exec(db, "create table if not exists migration_scripts(id int not null, init text not null, deinit text not null);");
}

pub fn cleanup_scripts(db: sql.sqlite3) void {
    sql.exec(db, "delete from migration_scripts;") catch {
        exit(1);
    };
}

pub fn add_to_scripts(allocator: mem.Allocator, db: sql.sqlite3, s: *Statements) !void {
    const stmt = try sql.prepare(db, "insert into migration_scripts(id, init, deinit) values($1, $2, $3)");
    try sql.bind_int(db, stmt, 1, @intCast(s.version));
    const init_t = try sql.Text.init(allocator, s.create, s.create_l);
    defer init_t.deinit();
    const deinit_t = try sql.Text.init(allocator, s.distruct, s.distruct_l);
    defer deinit_t.deinit();
    try sql.bind_text(db, 2, stmt, init_t, sql.TRANSIENT);
    try sql.bind_text(db, 3, stmt, deinit_t, sql.TRANSIENT);
    try sql.step(db, stmt);
    try sql.finalize(db, stmt);
}

pub fn get_scripts(allocator: mem.Allocator) !std.ArrayList(*Statements) {
    const db = try sql.init("data.db");
    defer sql.deinit(db) catch {
        exit(1);
    };
    const stmt = try sql.prepare(db, "select * from migration_scripts;");
    var stash = std.ArrayList(*Statements).init(allocator);
    while (sql.raw_step(stmt) != sql.DONE) {
        const version = sql.column_int(0, stmt);
        const init = try sql.column_text(1, stmt);
        const distruct = try sql.column_text(2, stmt);
        const init_span: [:0]const u8 = mem.span(init.ptr);
        const distruct_span: [:0]const u8 = mem.span(distruct.ptr);
        var statement = try Statements.init(1024, allocator, @intCast(version));
        mem.copyForwards(u8, statement.create, init_span);
        mem.copyForwards(u8, statement.distruct, distruct_span);
        statement.create_l = init_span.len;
        statement.distruct_l = distruct_span.len;
        try stash.append(statement);
        print("INFO: version: {d}, init: {s} distruct: {s}\n", .{ version, statement.create, statement.distruct });
    }
    try sql.finalize(db, stmt);
    return stash;
}

pub fn drop_scripts(allocator: mem.Allocator) !void {
    const db = try sql.init("data.db");
    defer sql.deinit(db) catch {
        exit(1);
    };
    print("INFO: trying to clear the db from previous version\n", .{});
    const scripts = try get_scripts(allocator);
    defer {
        for (scripts.items) |i| {
            i.deinit();
        }
        scripts.deinit();
    }
    for (scripts.items) |stmt| {
        print("INFO: trying to drop table: {s}\n", .{stmt.distruct});
        try drop_table(db, allocator, stmt);
    }

    print("DEBUG: trying to erase script stash\n", .{});
    try sql.exec(db, "delete from migration_scripts;");
}
