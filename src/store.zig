//! Lightweight binary persistence of the ResonanceField.
//! Version 2: also persists the bounded collapse log.
//! Uses std.c for file I/O (Zig compatibility without full Io plumbing).

const std = @import("std");
const field_mod = @import("field");
const ResonanceField = field_mod.ResonanceField;
const DIM = field_mod.DIM;
const LOG_CAPACITY = field_mod.LOG_CAPACITY;
const FP_LEN = field_mod.FP_LEN;
const CollapseEntry = field_mod.CollapseEntry;

const MAGIC: u32 = 0x43524344; // "CRCD"
const VERSION: u16 = 2; // bumped for log support

pub fn save(f: *const ResonanceField, path: []const u8) !void {
    const path_z = try std.heap.page_allocator.dupeZ(u8, path);
    defer std.heap.page_allocator.free(path_z);

    const file_opt = std.c.fopen(path_z.ptr, "wb");
    if (file_opt == null) return error.FileOpenFailed;
    const file = file_opt.?;
    defer _ = std.c.fclose(file);

    // Header: magic(4) + version(2) + pad(2) + collapse_count(8) + log_len(8) + log_head(8)
    var header: [32]u8 = undefined;
    @memset(&header, 0);
    std.mem.writeInt(u32, header[0..4], MAGIC, .little);
    std.mem.writeInt(u16, header[4..6], VERSION, .little);
    std.mem.writeInt(u64, header[8..16], f.collapse_count, .little);
    std.mem.writeInt(u64, header[16..24], @as(u64, f.log_len), .little);
    std.mem.writeInt(u64, header[24..32], @as(u64, f.log_head), .little);

    _ = std.c.fwrite(&header, 1, header.len, file);

    // State vector
    for (f.state) |v| {
        var bits: [8]u8 = undefined;
        std.mem.writeInt(u64, &bits, @bitCast(v), .little);
        _ = std.c.fwrite(&bits, 1, 8, file);
    }

    // Collapse log (always write full capacity for simplicity)
    for (f.log) |entry| {
        _ = std.c.fwrite(&entry.fingerprint, 1, FP_LEN, file);
        var sbits: [4]u8 = undefined;
        std.mem.writeInt(u32, &sbits, @bitCast(entry.strength), .little);
        _ = std.c.fwrite(&sbits, 1, 4, file);
        var seqbits: [8]u8 = undefined;
        std.mem.writeInt(u64, &seqbits, entry.sequence, .little);
        _ = std.c.fwrite(&seqbits, 1, 8, file);
    }
}

pub fn load(path: []const u8) !ResonanceField {
    const path_z = try std.heap.page_allocator.dupeZ(u8, path);
    defer std.heap.page_allocator.free(path_z);

    const file_opt = std.c.fopen(path_z.ptr, "rb");
    if (file_opt == null) return error.FileOpenFailed;
    const file = file_opt.?;
    defer _ = std.c.fclose(file);

    var header: [32]u8 = undefined;
    const n = std.c.fread(&header, 1, header.len, file);
    // Accept both old (16-byte) and new (32-byte) headers for migration
    if (n < 16) return error.UnexpectedEof;

    const magic = std.mem.readInt(u32, header[0..4], .little);
    if (magic != MAGIC) return error.InvalidMagic;

    const version = std.mem.readInt(u16, header[4..6], .little);
    if (version != 1 and version != 2) return error.UnsupportedVersion;

    const collapse_count = std.mem.readInt(u64, header[8..16], .little);

    var f = ResonanceField.init();
    f.collapse_count = collapse_count;

    // Read state vector
    var i: usize = 0;
    while (i < DIM) : (i += 1) {
        var bits: [8]u8 = undefined;
        const rn = std.c.fread(&bits, 1, 8, file);
        if (rn != 8) return error.UnexpectedEof;
        f.state[i] = @bitCast(std.mem.readInt(u64, &bits, .little));
    }

    if (version >= 2 and n >= 32) {
        f.log_len = @intCast(std.mem.readInt(u64, header[16..24], .little));
        f.log_head = @intCast(std.mem.readInt(u64, header[24..32], .little));
        if (f.log_len > LOG_CAPACITY) f.log_len = LOG_CAPACITY;
        if (f.log_head >= LOG_CAPACITY) f.log_head = 0;

        var j: usize = 0;
        while (j < LOG_CAPACITY) : (j += 1) {
            var entry: CollapseEntry = undefined;
            const rn1 = std.c.fread(&entry.fingerprint, 1, FP_LEN, file);
            if (rn1 != FP_LEN) break;
            var sbits: [4]u8 = undefined;
            const rn2 = std.c.fread(&sbits, 1, 4, file);
            if (rn2 != 4) break;
            entry.strength = @bitCast(std.mem.readInt(u32, &sbits, .little));
            var seqbits: [8]u8 = undefined;
            const rn3 = std.c.fread(&seqbits, 1, 8, file);
            if (rn3 != 8) break;
            entry.sequence = std.mem.readInt(u64, &seqbits, .little);
            f.log[j] = entry;
        }
    }

    return f;
}
