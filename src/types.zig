const std = @import("std");
const tuple = std.meta.Tuple;

pub const Route = tuple(&.{ []const u8, *const fn () Response });

pub const Header = tuple(&.{ []const u8, *const fn () Response });

pub const HTTP_Version = enum([]const u8) { HTTP1_1 = "HTTP/1.1", HTTP2 = "HTTP/" };

pub const Request = struct {
    httpVersion: HTTP_Version,
    headers: std.ArrayList,
    body: std.ArrayList,
};

pub const Response = struct {
    httpVersion: HTTP_Version = HTTP_Version.HTTP1_1,
    headers: std.ArrayList,
    body: std.ArrayList,
};
