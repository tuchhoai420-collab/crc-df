//! Binary persistence via libc stdio (portable across Zig 0.14–0.16).
//! Avoids std.fs / std.Io churn between releases.

const std = @import("std");
const field_mod = @import("field");
const ResonanceField = field_mod.ResonanceField;
const DIM = field_mod.DIM;
const LOG_CAPACITY = field_mod.LOG_CAPACITY;
const FP_LEN = field_mod.FP_LEN;
const CollapseEntry = field_mod.CollapseEntry;

const MAGIC: u32 = 0x43524344; // "CRCD"
const VERSION: u16 = 3;

fn cWrite(file: *std.c.FILE, bytes: []const u8) !void {
    if (bytes.len == 0) return;
    const n = std.c.fwrite(bytes.ptr, 1, bytes.len, file);
    if (n != bytes.len) return error.WriteFailed;
}

fn cRead(file: *std.c.FILE, buf: []u8) !void {
    if (buf.len == 0) return;
    const n = std.c.fread(buf.ptr, 1, buf.len, file);
    if (n != buf.len) return error.UnexpectedEof;
}

fn writeU16(file: *std.c.FILE, v: u16) !void {
    var b: [2]u8 = undefined;
    std.mem.writeInt(u16, &b, v, .little);
    try cWrite(file, &b);
}

fn writeU32(file: *std.c.FILE, v: u32) !void {
    var b: [4]u8 = undefined;
    std.mem.writeInt(u32, &b, v, .little);
    try cWrite(file, &b);
}

fn writeU64(file: *std.c.FILE, v: u64) !void {
    var b: [8]u8 = undefined;
    std.mem.writeInt(u64, &b, v, .little);
    try cWrite(file, &b);
}

fn readU16(file: *std.c.FILE) !u16 {
    var b: [2]u8 = undefined;
    try cRead(file, &b);
    return std.mem.readInt(u16, &b, .little);
}

fn readU32(file: *std.c.FILE) !u32 {
    var b: [4]u8 = undefined;
    try cRead(file, &b);
    return std.mem.readInt(u32, &b, .little);
}

fn readU64(file: *std.c.FILE) !u64 {
    var b: [8]u8 = undefined;
    try cRead(file, &b);
    return std.mem.readInt(u64, &b, .little);
}

pub fn save(f: *const ResonanceField, path: []const u8) !void {
    const path_z = try std.heap.page_allocator.dupeZ(u8, path);
    defer std.heap.page_allocator.free(path_z);

    const file_opt = std.c.fopen(path_z.ptr, "wb");
    if (file_opt == null) return error.FileOpenFailed;
    const file = file_opt.?;
    defer _ = std.c.fclose(file);

    try writeU32(file, MAGIC);
    try writeU16(file, VERSION);
    try writeU16(file, 0); // pad
    try writeU64(file, f.collapse_count);
    try writeU64(file, @as(u64, f.log_len));
    try writeU64(file, @as(u64, f.log_head));

    for (f.state) |v| {
        try writeU64(file, @bitCast(v));
    }

    for (&f.log) |*entry| {
        try cWrite(file, entry.fingerprint[0..]);
        try writeU32(file, @bitCast(entry.strength));
        try writeU64(file, entry.sequence);
    }
}

pub fn load(path: []const u8) !ResonanceField {
    const path_z = try std.heap.page_allocator.dupeZ(u8, path);
    defer std.heap.page_allocator.free(path_z);

    const file_opt = std.c.fopen(path_z.ptr, "rb");
    if (file_opt == null) return error.FileOpenFailed;
    const file = file_opt.?;
    defer _ = std.c.fclose(file);

    const magic = try readU32(file);
    if (magic != MAGIC) return error.InvalidMagic;

    const version = try readU16(file);
    _ = try readU16(file); // pad
    if (version != 2 and version != 3) return error.UnsupportedVersion;

    const collapse_count = try readU64(file);
    const log_len = try readU64(file);
    const log_head = try readU64(file);

    var f = ResonanceField.init();
    f.collapse_count = collapse_count;
    f.log_len = @intCast(@min(log_len, @as(u64, LOG_CAPACITY)));
    f.log_head = @intCast(@min(log_head, @as(u64, LOG_CAPACITY - 1)));

    var i: usize = 0;
    while (i < DIM) : (i += 1) {
        f.state[i] = @bitCast(try readU64(file));
    }

    var j: usize = 0;
    while (j < LOG_CAPACITY) : (j += 1) {
        var entry: CollapseEntry = .{
            .fingerprint = [_]u8{0} ** FP_LEN,
            .strength = 0,
            .sequence = 0,
        };
        try cRead(file, entry.fingerprint[0..]);
        entry.strength = @bitCast(try readU32(file));
        entry.sequence = try readU64(file);
        f.log[j] = entry;
    }

    return f;
}
