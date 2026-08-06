//! Lightweight binary persistence of the ResonanceField.
//! Uses std.c for file I/O (Zig 0.16 compatibility without full Io plumbing).

const std = @import("std");
const field_mod = @import("field");
const ResonanceField = field_mod.ResonanceField;
const DIM = field_mod.DIM;

const MAGIC: u32 = 0x43524344; // "CRCD"
const VERSION: u16 = 1;

pub fn save(f: *const ResonanceField, path: []const u8) !void {
    const path_z = try std.heap.page_allocator.dupeZ(u8, path);
    defer std.heap.page_allocator.free(path_z);

    const file = std.c.fopen(path_z.ptr, "wb");
    if (file == null) return error.FileOpenFailed;
    defer _ = std.c.fclose(file);

    var header: [16]u8 = undefined;
    std.mem.writeInt(u32, header[0..4], MAGIC, .little);
    std.mem.writeInt(u16, header[4..6], VERSION, .little);
    std.mem.writeInt(u16, header[6..8], 0, .little);
    std.mem.writeInt(u64, header[8..16], f.collapse_count, .little);

    _ = std.c.fwrite(&header, 1, header.len, file);

    for (f.state) |v| {
        var bits: [8]u8 = undefined;
        std.mem.writeInt(u64, &bits, @bitCast(v), .little);
        _ = std.c.fwrite(&bits, 1, 8, file);
    }
}

pub fn load(path: []const u8) !ResonanceField {
    const path_z = try std.heap.page_allocator.dupeZ(u8, path);
    defer std.heap.page_allocator.free(path_z);

    const file = std.c.fopen(path_z.ptr, "rb");
    if (file == null) return error.FileOpenFailed;
    defer _ = std.c.fclose(file);

    var header: [16]u8 = undefined;
    const n = std.c.fread(&header, 1, header.len, file);
    if (n != header.len) return error.UnexpectedEof;

    const magic = std.mem.readInt(u32, header[0..4], .little);
    if (magic != MAGIC) return error.InvalidMagic;

    const version = std.mem.readInt(u16, header[4..6], .little);
    if (version != VERSION) return error.UnsupportedVersion;

    const collapse_count = std.mem.readInt(u64, header[8..16], .little);

    var f = ResonanceField.init();
    f.collapse_count = collapse_count;

    var i: usize = 0;
    while (i < DIM) : (i += 1) {
        var bits: [8]u8 = undefined;
        const rn = std.c.fread(&bits, 1, 8, file);
        if (rn != 8) return error.UnexpectedEof;
        f.state[i] = @bitCast(std.mem.readInt(u64, &bits, .little));
    }

    return f;
}
