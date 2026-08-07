//! Binary persistence of the ResonanceField + bounded collapse log.
//! Uses std.fs for reliable I/O across Zig 0.14–0.16 and NetHunter.

const std = @import("std");
const field_mod = @import("field");
const ResonanceField = field_mod.ResonanceField;
const DIM = field_mod.DIM;
const LOG_CAPACITY = field_mod.LOG_CAPACITY;
const FP_LEN = field_mod.FP_LEN;
const CollapseEntry = field_mod.CollapseEntry;

const MAGIC: u32 = 0x43524344; // "CRCD"
const VERSION: u16 = 3;

fn writeU16(file: std.fs.File, v: u16) !void {
    var b: [2]u8 = undefined;
    std.mem.writeInt(u16, &b, v, .little);
    try file.writeAll(&b);
}

fn writeU32(file: std.fs.File, v: u32) !void {
    var b: [4]u8 = undefined;
    std.mem.writeInt(u32, &b, v, .little);
    try file.writeAll(&b);
}

fn writeU64(file: std.fs.File, v: u64) !void {
    var b: [8]u8 = undefined;
    std.mem.writeInt(u64, &b, v, .little);
    try file.writeAll(&b);
}

fn writeF32(file: std.fs.File, v: f32) !void {
    try writeU32(file, @bitCast(v));
}

fn writeF64(file: std.fs.File, v: f64) !void {
    try writeU64(file, @bitCast(v));
}

fn readExact(file: std.fs.File, buf: []u8) !void {
    const n = try file.readAll(buf);
    if (n != buf.len) return error.UnexpectedEof;
}

fn readU16(file: std.fs.File) !u16 {
    var b: [2]u8 = undefined;
    try readExact(file, &b);
    return std.mem.readInt(u16, &b, .little);
}

fn readU32(file: std.fs.File) !u32 {
    var b: [4]u8 = undefined;
    try readExact(file, &b);
    return std.mem.readInt(u32, &b, .little);
}

fn readU64(file: std.fs.File) !u64 {
    var b: [8]u8 = undefined;
    try readExact(file, &b);
    return std.mem.readInt(u64, &b, .little);
}

fn readF32(file: std.fs.File) !f32 {
    return @bitCast(try readU32(file));
}

fn readF64(file: std.fs.File) !f64 {
    return @bitCast(try readU64(file));
}

pub fn save(f: *const ResonanceField, path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try writeU32(file, MAGIC);
    try writeU16(file, VERSION);
    try writeU16(file, 0); // pad
    try writeU64(file, f.collapse_count);
    try writeU64(file, @as(u64, f.log_len));
    try writeU64(file, @as(u64, f.log_head));

    for (f.state) |v| {
        try writeF64(file, v);
    }

    for (f.log) |entry| {
        try file.writeAll(&entry.fingerprint);
        try writeF32(file, entry.strength);
        try writeU64(file, entry.sequence);
    }
}

pub fn load(path: []const u8) !ResonanceField {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

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
    f.log_len = @intCast(@min(log_len, LOG_CAPACITY));
    f.log_head = @intCast(@min(log_head, LOG_CAPACITY - 1));

    var i: usize = 0;
    while (i < DIM) : (i += 1) {
        f.state[i] = try readF64(file);
    }

    // v2 may have been written with FP_LEN=48; v3 always uses current FP_LEN
    // For v2 with wrong size, we still try current layout (user should reset).
    var j: usize = 0;
    while (j < LOG_CAPACITY) : (j += 1) {
        var entry: CollapseEntry = .{
            .fingerprint = [_]u8{0} ** FP_LEN,
            .strength = 0,
            .sequence = 0,
        };
        try readExact(file, entry.fingerprint[0..]);
        entry.strength = try readF32(file);
        entry.sequence = try readU64(file);
        f.log[j] = entry;
    }

    return f;
}
