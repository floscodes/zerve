const std = @import("std");
const types = @import("types.zig");

pub const Cookie = struct {
    name: []const u8,
    value: []const u8,
    path: []const u8 = "/",
    domain: []const u8 = "",
    /// Indicates the number of seconds until the cookie expires.
    maxAge: i64 = 0,
    secure: bool = true,
    httpOnly: bool = true,
    sameSite: SameSite = .lax,

    pub fn stringify(self: Cookie, allocator: std.mem.Allocator) ![]const u8 {
        const domain = if (std.mem.eql(u8, self.domain, "")) self.domain else try std.fmt.allocPrint(allocator, "Domain={s}; ", .{self.domain});
        defer allocator.free(domain);
        const secure = if (self.secure) "Secure; " else "";
        const httpOnly = if (self.httpOnly) "HttpOnly; " else "";
        return try std.fmt.allocPrint(allocator, "Set-Cookie: {s}={s}; Path={s}; {s}Max-Age={}; {s}{s}{s}", .{ self.name, self.value, self.path, domain, self.maxAge, secure, httpOnly, getSameSite(&self) });
    }
};

pub const SameSite = enum {
    lax,
    strict,
    none,
};

pub fn getSameSite(c: *const Cookie) []const u8 {
    switch (c.sameSite) {
        .lax => return "SameSite=Lax;",
        .strict => return "SameSite=Strict;",
        .none => return "SameSite=None;",
    }
}
