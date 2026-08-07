//! Persistent user profile — identity memory.
//!
//! Rules:
//! - Survives resets of the geometric field.
//! - Does NOT decay with sleep.
//! - Entries are only removed by explicit forget(id).
//! - Format (one entry per line): kind|id|text
//!
//! kinds: preference | methodology | constraint | topic

const std = @import("std");

pub const PROFILE_PATH = "crc_df_profile.txt";
pub const MAX_ENTRIES = 128;
pub const MAX_TEXT = 240;

pub const Kind = enum {
    preference,
    methodology,
    constraint,
    topic,

    pub fn fromString(s: []const u8) ?Kind {
        if (std.mem.eql(u8, s, "preference") or std.mem.eql(u8, s, "pref")) return .preference;
        if (std.mem.eql(u8, s, "methodology") or std.mem.eql(u8, s, "method")) return .methodology;
        if (std.mem.eql(u8, s, "constraint") or std.mem.eql(u8, s, "rule")) return .constraint;
        if (std.mem.eql(u8, s, "topic")) return .topic;
        return null;
    }

    pub fn toString(self: Kind) []const u8 {
        return switch (self) {
            .preference => "preference",
            .methodology => "methodology",
            .constraint => "constraint",
            .topic => "topic",
        };
    }
};

pub const Entry = struct {
    id: u32,
    kind: Kind,
    text: [MAX_TEXT]u8 = [_]u8{0} ** MAX_TEXT,
    text_len: usize = 0,

    pub fn textSlice(self: *const Entry) []const u8 {
        return self.text[0..self.text_len];
    }
};

pub const Profile = struct {
    entries: [MAX_ENTRIES]Entry = undefined,
    len: usize = 0,
    next_id: u32 = 1,

    pub fn empty() Profile {
        return .{};
    }

    pub fn load(path: []const u8) Profile {
        var p = Profile.empty();
        const path_z = std.heap.page_allocator.dupeZ(u8, path) catch return p;
        defer std.heap.page_allocator.free(path_z);

        const file_opt = std.c.fopen(path_z.ptr, "rb");
        if (file_opt == null) return p;
        const file = file_opt.?;
        defer _ = std.c.fclose(file);

        var line_buf: [512]u8 = undefined;
        while (std.c.fgets(&line_buf, line_buf.len, file) != null) {
            var line_len: usize = 0;
            while (line_len < line_buf.len and line_buf[line_len] != 0) : (line_len += 1) {}
            while (line_len > 0 and (line_buf[line_len - 1] == '\n' or line_buf[line_len - 1] == '\r')) : (line_len -= 1) {}
            const line = line_buf[0..line_len];
            if (line.len == 0 or line[0] == '#') continue;

            const sep1 = std.mem.indexOfScalar(u8, line, '|') orelse continue;
            const rest = line[sep1 + 1 ..];
            const sep2 = std.mem.indexOfScalar(u8, rest, '|') orelse continue;
            const kind_s = line[0..sep1];
            const id_s = rest[0..sep2];
            const text_s = rest[sep2 + 1 ..];

            const kind = Kind.fromString(kind_s) orelse continue;
            const id = std.fmt.parseInt(u32, id_s, 10) catch continue;
            if (p.len >= MAX_ENTRIES) break;

            var e: Entry = .{ .id = id, .kind = kind };
            const copy_len = @min(text_s.len, MAX_TEXT);
            @memcpy(e.text[0..copy_len], text_s[0..copy_len]);
            e.text_len = copy_len;
            p.entries[p.len] = e;
            p.len += 1;
            if (id >= p.next_id) p.next_id = id + 1;
        }
        return p;
    }

    pub fn save(self: *const Profile, path: []const u8) !void {
        const path_z = try std.heap.page_allocator.dupeZ(u8, path);
        defer std.heap.page_allocator.free(path_z);

        const file_opt = std.c.fopen(path_z.ptr, "wb");
        if (file_opt == null) return error.FileOpenFailed;
        const file = file_opt.?;
        defer _ = std.c.fclose(file);

        const header = "# CRC-DF user profile - persistent; remove only via explicit forget\n# kind|id|text\n";
        _ = std.c.fwrite(header.ptr, 1, header.len, file);

        var i: usize = 0;
        while (i < self.len) : (i += 1) {
            const e = self.entries[i];
            var line: [600]u8 = undefined;
            const formatted = std.fmt.bufPrint(&line, "{s}|{d}|{s}\n", .{
                e.kind.toString(),
                e.id,
                e.textSlice(),
            }) catch continue;
            _ = std.c.fwrite(formatted.ptr, 1, formatted.len, file);
        }
    }

    pub fn add(self: *Profile, kind: Kind, text: []const u8) !u32 {
        if (self.len >= MAX_ENTRIES) return error.ProfileFull;
        var i: usize = 0;
        while (i < self.len) : (i += 1) {
            const e = self.entries[i];
            if (e.kind == kind and std.mem.eql(u8, e.textSlice(), text)) {
                return e.id;
            }
        }
        const id = self.next_id;
        self.next_id += 1;
        var e: Entry = .{ .id = id, .kind = kind };
        const copy_len = @min(text.len, MAX_TEXT);
        @memcpy(e.text[0..copy_len], text[0..copy_len]);
        e.text_len = copy_len;
        self.entries[self.len] = e;
        self.len += 1;
        return id;
    }

    pub fn forget(self: *Profile, id: u32) bool {
        var i: usize = 0;
        while (i < self.len) : (i += 1) {
            if (self.entries[i].id == id) {
                var j = i;
                while (j + 1 < self.len) : (j += 1) {
                    self.entries[j] = self.entries[j + 1];
                }
                self.len -= 1;
                return true;
            }
        }
        return false;
    }
};
