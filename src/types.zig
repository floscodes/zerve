const std = @import("std");
const tuple = std.meta.Tuple;
const stat = @import("./status.zig");

/// Route is a touple that consists of the path and the function that shall handle it.
/// e.g. `const rt = Route{"/home", home};`
/// It it usual that a webapp handles more than one path so you can declare an array of `Route`
/// e.g. `const rt =[_]Route{.{"/index", index}, .{"/home", home}};`
pub const Route = tuple(&.{ []const u8, *const fn (Request) Response });

/// A header of a `Request` or a `Response`.
/// It is usual that more than one is sent, so you can declare an array.
pub const Header = tuple(&.{ []const u8, []const u8 });

/// The HTTP Version.
pub const HTTP_Version = enum { HTTP1_1, HTTP2 };

/// Represents the Method of a request or a response.
pub const Method = enum { GET, POST, PUT, HEAD, DELETE, CONNECT, OPTIONS, TRACE, PATCH };

/// Represents a standard http-Request sent by the client.
pub const Request = struct {
    /// The Request Method, e.g. "GET"
    method: Method,
    /// HTTP-Version of the Request sent by the client
    httpVersion: HTTP_Version,
    /// Represents the request headers sent by the client
    headers: []Header,
    /// Represents the request body sent by the client
    body: []u8,
};

/// Represents a standard http-Response sent by the webapp (server).
/// It is the return type of every handling function.
pub const Response = struct {
    /// Response status, default is "200 OK"
    status: stat.Status = stat.Status.OK,
    /// Response eaders sent by the server
    headers: []Header,
    /// Response body sent by the server
    body: []u8,
};
