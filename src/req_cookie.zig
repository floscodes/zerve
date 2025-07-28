const std = @import("std");
const trim = std.mem.trim;
const split = std.mem.splitSequence;
const olderVersion: bool = @import("builtin").zig_version.minor < 11;

pub const Cookie = struct {
    name: []const u8,
    value: []const u8,

    pub fn parse(item2: []const u8, allocator: std.mem.Allocator) ![]const Cookie {
        var items = split(u8, item2, ";");
        var cookie_buffer = std.ArrayList(Cookie).init(allocator);
        var cookie_string = split(u8, items.first(), "=");
        const first_cookie = Cookie{ .name = trim(u8, cookie_string.first(), " "), .value = trim(u8, cookie_string.next().?, " ") };
        try cookie_buffer.append(first_cookie);

        while (items.next()) |item| {
            cookie_string = split(u8, item, "=");
            const name = trim(u8, cookie_string.first(), " ");
            const value = if (cookie_string.next()) |v| trim(u8, v, " ") else "";
            const cookie = Cookie{ .name = name, .value = value };
            try cookie_buffer.append(cookie);
        }
        return if (olderVersion) cookie_buffer.toOwnedSlice() else try cookie_buffer.toOwnedSlice();
    }
};

test "Parse Request Cookie(s)" {
    const allocator = std.testing.allocator;
    const cookie_string = "Test-Cookie=successful; Second-Cookie=also successful";
    const cookie = try Cookie.parse(cookie_string, allocator);
    defer allocator.free(cookie);
    try std.testing.expect(std.mem.eql(u8, cookie[0].value, "successful"));
    try std.testing.expect(std.mem.eql(u8, cookie[0].name, "Test-Cookie"));
    try std.testing.expect(std.mem.eql(u8, cookie[1].name, "Second-Cookie"));
    try std.testing.expect(std.mem.eql(u8, cookie[1].value, "also successful"));
}
