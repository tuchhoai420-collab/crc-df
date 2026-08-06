//! Lightweight binary persistence of the ResonanceField.
//! Only the fixed-size state + minimal metadata is stored.

const std = @import("std");
const field_mod = @import("field");
const ResonanceField = field_mod.ResonanceField;
const DIM = field_mod.DIM;

const MAGIC: u32 = 0x43524344; // "CRCD"
const VERSION: u16 = 1;

pub fn save(f: *const ResonanceField, path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var buf: [8 + 8 + DIM * 8]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const w = stream.writer();

    try w.writeInt(u32, MAGIC, .little);
    try w.writeInt(u16, VERSION, .little);
    try w.writeInt(u16, 0, .little); // reserved
    try w.writeInt(u64, f.collapse_count, .little);

    for (f.state) |v| {
        try w.writeInt(u64, @bitCast(v), .little);
    }

    try file.writeAll(stream.getWritten());
}

pub fn load(path: []const u8) !ResonanceField {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var header: [16]u8 = undefined;
    _ = try file.readAll(&header);

    const magic = std.mem.readInt(u32, header[0..4], .little);
    if (magic != MAGIC) return error.InvalidMagic;

    const version = std.mem.readInt(u16, header[4..6], .little);
    if (version != VERSION) return error.UnsupportedVersion;

    const collapse_count = std.mem.readInt(u64, header[8..16], .little);

    var f = ResonanceField.init();
    f.collapse_count = collapse_count;

    var raw: [DIM * 8]u8 = undefined;
    _ = try file.readAll(&raw);

    var i: usize = 0;
    while (i < DIM) : (i += 1) {
        const bits = std.mem.readInt(u64, raw[i * 8 ..][0..8], .little);
        f.state[i] = @bitCast(bits);
    }

    return f;
}
