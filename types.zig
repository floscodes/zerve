const tuple = @import("std").meta.Tuple;

pub const Route = tuple(&.{ []const u8, *const fn () Response });

pub const Header = tuple(&.{ []const u8, *const fn () Response });

pub const HTTP_Version = enum {
    HTTP1_1,
    HTTP2,
};

pub const Request = struct {
    httpVersion: HTTP_Version,
    headers: []Header,
    body: []u8,
};

pub const Response = struct {
    httpVersion: HTTP_Version,
    headers: []Header,
    body: []u8,
};
