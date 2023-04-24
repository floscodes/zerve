const std = @import("std");
const tuple = std.meta.Tuple;
const allocator = std.heap.page_allocator;
const stat = @import("./status.zig");

/// Route is a touple that consists of the path and the function that shall handle it.
/// e.g. `const rt = Route{"/home", home};`
/// It it usual that a webapp handles more than one path so you can declare an array of `Route`
/// e.g. `const rt =[_]Route{.{"/index", index}, .{"/home", home}};`
pub const Route = tuple(&.{ []const u8, *const fn (Request) Response });

/// A header of a `Request` or a `Response`.
/// It is usual that more than one is sent, so you can declare an array.
pub const Header = struct {
    key: []const u8,
    value: []const u8,

    /// Turns the header key and value into a string.
    pub fn stringify(header: Header) []const u8 {
        var string = std.ArrayList(u8).init(allocator);
        string.appendSlice(header.key) catch unreachable;
        string.appendSlice(": ") catch unreachable;
        string.appendSlice(header.value) catch unreachable;
        const out = string.toOwnedSlice() catch "";
        return out;
    }

    test "stringify Header" {
        var header = Header{ .key = "User-Agent", .value = "Testbot" };
        const compare = "User-Agent: Testbot";
        try std.testing.expect(std.mem.eql(u8, header.stringify(), compare[0..]));
    }
};

/// The HTTP Version.
pub const HTTP_Version = enum {
    HTTP1_1,
    HTTP2,
    
    /// Parses from `[]u8`
    pub fn parse(s: []const u8) HTTP_Version {
        if (std.mem.containsAtLeast(u8, s, 1, "2")) return HTTP_Version.HTTP2 else return HTTP_Version.HTTP1_1;
    }
    /// Stringifies `HTTP_Version`
    pub fn stringify(version: HTTP_Version) []const u8 {
        switch (version) {
            HTTP_Version.HTTP1_1 => return "HTTP/1.1",
            HTTP_Version.HTTP2 => return "HTTP/2.0",
        }
    }
};

/// Represents the Method of a request or a response.
pub const Method = enum {
    GET,
    POST,
    PUT,
    HEAD,
    DELETE,
    CONNECT,
    OPTIONS,
    TRACE,
    PATCH,
    UNKNOWN,

    fn parse(value: []const u8) Method {
        if (std.mem.containsAtLeast(u8, value, 1, "GET")) return Method.GET;
        if (std.mem.containsAtLeast(u8, value, 1, "POST")) return Method.POST;
        if (std.mem.containsAtLeast(u8, value, 1, "PUT")) return Method.PUT;
        if (std.mem.containsAtLeast(u8, value, 1, "HEAD")) return Method.HEAD;
        if (std.mem.containsAtLeast(u8, value, 1, "DELETE")) return Method.DELETE;
        if (std.mem.containsAtLeast(u8, value, 1, "CONNECT")) return Method.CONNECT;
        if (std.mem.containsAtLeast(u8, value, 1, "OPTIONS")) return Method.OPTIONS;
        if (std.mem.containsAtLeast(u8, value, 1, "TRACE")) return Method.TRACE;
        if (std.mem.containsAtLeast(u8, value, 1, "PATCH")) return Method.PATCH;
        return Method.UNKNOWN;
    }

    /// Turns the HTTP_method into a u8-Slice.
    pub fn stringify(m: Method) []const u8 {
        switch (m) {
            Method.GET => return "GET",
            Method.POST => return "POST",
            Method.PUT => return "PUT",
            Method.PATCH => return "PATCH",
            Method.DELETE => return "DELETE",
            Method.HEAD => return "HEAD",
            Method.CONNECT => return "CONNECT",
            Method.OPTIONS => return "OPTIONS",
            Method.TRACE => return "TRACE",
            Method.UNKNOWN => return "UNKNOWN",
        }
    }
};

/// Represents a standard http-Request sent by the client.
pub const Request = struct {
    /// The Request Method, e.g. "GET"
    method: Method,
    /// HTTP-Version of the Request sent by the client
    httpVersion: HTTP_Version,
    /// Represents the request headers sent by the client
    headers: []const Header,
    /// Teh Request URI
    uri: []const u8,
    /// Represents the request body sent by the client
    body: []const u8,

    pub fn build(bytes: []const u8) !Request {
        var req: Request = undefined;
        var parts = std.mem.split(u8, bytes, "\r\n");
        const header = parts.first();
        var header_lines = std.mem.split(u8, header, "\n");
        var header_buffer = std.ArrayList(Header).init(allocator);

        var header_items = std.mem.split(u8, header_lines.first(), " ");
        req.method = Method.parse(header_items.first());
        req.uri = if (header_items.next()) |value| value else "";

        if (header_items.next()) |value| {
            req.httpVersion = HTTP_Version.parse(value);
        } else {
            req.httpVersion = HTTP_Version.HTTP1_1;
        }

        while (header_lines.next()) |line| {
            var headers = std.mem.split(u8, line, ": ");
            const item1 = headers.first();
            const item2 = if (headers.next()) |value| value else unreachable;
            const header_pair = Header{ .key = item1, .value = item2 };
            try header_buffer.append(header_pair);
        }
        req.headers = header_buffer.toOwnedSlice() catch &[_]Header{Header{ .key = "", .value = "" }};
        req.body = if (parts.next()) |value| value else "";
        return req;
    }

    // Test the Request build function
    test "build a Request" {
        const bytes = "GET /test HTTP/1.1\nHost: localhost:8080\nUser-Agent: Testbot\r\nThis is the test body!";
        const req = try Request.build(bytes);
        try std.testing.expect(req.method == Method.GET);
        try std.testing.expect(req.httpVersion == HTTP_Version.HTTP1_1);
        try std.testing.expect(std.mem.eql(u8, req.uri, "/test"));
        try std.testing.expect(std.mem.eql(u8, req.headers[1].key, "User-Agent"));
        try std.testing.expect(std.mem.eql(u8, req.headers[1].value, "Testbot"));
        try std.testing.expect(std.mem.eql(u8, req.headers[0].key, "Host"));
        try std.testing.expect(std.mem.eql(u8, req.headers[0].value, "localhost:8080"));
        try std.testing.expect(std.mem.eql(u8, req.body, "This is the test body!"));
    }
};

/// Represents a standard http-Response sent by the webapp (server).
/// It is the return type of every handling function.
pub const Response = struct {
    httpVersion: HTTP_Version = HTTP_Version.HTTP1_1,
    /// Response status, default is "200 OK"
    status: stat.Status = stat.Status.OK,
    /// Response eaders sent by the server
    headers: []const Header = &[_]Header{.{ .key = "Content-Type", .value = "text/html; charset=utf-8" }},
    /// Response body sent by the server
    body: []const u8 = "",

    /// Write a simple response.
    pub fn new(s: []const u8) Response {
        return Response{ .body = s };
    }

    /// Send a response with json content.
    pub fn json(j: []const u8) Response {
        return Response{ .headers = &[_]Header{.{ .key = "Content-Type", .value = "application/json" }}, .body = j };
    }

    /// Send a response with status not found.
    pub fn notfound(s: []const u8) Response {
        return Response{ .status = stat.Status.NOT_FOUND, .body = s };
    }

    /// Send a response with status forbidden.
    pub fn forbidden(s: []u8) Response {
        return Response{ .status = stat.Status.FORBIDDEN, .body = s };
    }
};

// Run all tests, even the nested ones
test {
    std.testing.refAllDecls(@This());
}
