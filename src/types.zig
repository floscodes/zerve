const std = @import("std");
const tuple = std.meta.Tuple;
const allocator = std.heap.page_allocator;
const eql = std.mem.eql;
const stat = @import("./status.zig");
const rescookie = @import("./res_cookie.zig");
const reqcookie = @import("./req_cookie.zig");

/// Route is a touple that consists of the path and the function that shall handle it.
/// e.g. `const rt = Route{"/home", home};`
/// It it usual that a webapp handles more than one path so you can declare an array of `Route`
/// e.g. `const rt =[_]Route{.{"/index", index}, .{"/home", home}};`
pub const Route = tuple(&.{ []const u8, *const fn (*Request) Response });

/// A header of a `Request` or a `Response`.
/// It is usual that more than one is sent, so you can declare an array.
pub const Header = struct {
    key: []const u8,
    value: []const u8,
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

    /// Parses the Method from a string
    pub fn parse(value: []const u8) Method {
        if (eql(u8, value, "GET") or eql(u8, value, "get")) return Method.GET;
        if (eql(u8, value, "POST") or eql(u8, value, "post")) return Method.POST;
        if (eql(u8, value, "PUT") or eql(u8, value, "put")) return Method.PUT;
        if (eql(u8, value, "HEAD") or eql(u8, value, "head")) return Method.HEAD;
        if (eql(u8, value, "DELETE") or eql(u8, value, "delete")) return Method.DELETE;
        if (eql(u8, value, "CONNECT") or eql(u8, value, "connect")) return Method.CONNECT;
        if (eql(u8, value, "OPTIONS") or eql(u8, value, "options")) return Method.OPTIONS;
        if (eql(u8, value, "TRACE") or eql(u8, value, "trace")) return Method.TRACE;
        if (eql(u8, value, "PATCH") or eql(u8, value, "patch")) return Method.PATCH;
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
    /// Represents the client's IP-Address.
    ip: []const u8,
    /// Represents the request headers sent by the client
    headers: []const Header,
    /// Request Cookies
    cookies: []const Cookie,
    /// The Request URI
    uri: []const u8,
    /// Represents the request body sent by the client
    body: []const u8,
    /// Represents a Request Cookie
    pub const Cookie = reqcookie.Cookie;

    /// Get Request Cookie value by Cookie name
    pub fn cookie(self: *Request, name: []const u8) ?[]const u8 {
        for (self.*.cookies) |c| {
            if (eql(u8, name, c.name)) return c.value;
        }
        return null;
    }

    /// Get Header value by Header key
    pub fn header(self: *Request, key: []const u8) ?[]const u8 {
        for (self.*.headers) |h| {
            if (eql(u8, key, h.key)) return h.value;
        }
        return null;
    }

    /// Get query value by query key
    pub fn getQuery(self: *Request, key_needle: []const u8) ?[]const u8 {
        var query_string: ?[]const u8 = null;
        if (self.method == .GET) {
            var parts = std.mem.split(u8, self.uri, "?");
            _ = parts.first();
            query_string = parts.next();
        }
        if (self.method == .POST) {
            query_string = self.body;
        }
        if (query_string == null) return null;
        var pairs = std.mem.split(u8, query_string.?, "&");
        var first_pair = pairs.first();
        var items = std.mem.split(u8, first_pair, "=");
        var key = items.first();
        if (eql(u8, key_needle, key)) {
            if (items.next()) |value| return value;
        }
        while (pairs.next()) |pair| {
            items = std.mem.split(u8, pair, "=");
            key = items.first();
            if (eql(u8, key_needle, key)) {
                if (items.next()) |value| return value;
            }
        }
        return null;
    }

    test "get Query" {
        var req: Request = undefined;
        req.uri = "/about/?user=james&password=1234"; // Write query string in uri after '?'
        req.method = .GET;
        var user = if (req.getQuery("user")) |v| v else "";
        var pwd = if (req.getQuery("password")) |v| v else "";
        var n = req.getQuery("nothing"); // This key does not exist in query string

        try std.testing.expect(eql(u8, user, "james"));
        try std.testing.expect(eql(u8, pwd, "1234"));
        try std.testing.expect(n == null);

        // Change method an write query string into body
        req.body = "user=james&password=1234";
        req.method = .POST;

        user = if (req.getQuery("user")) |v| v else "";
        pwd = if (req.getQuery("password")) |v| v else "";
        n = req.getQuery("nothing"); // This key does not exist in query string

        try std.testing.expect(eql(u8, user, "james"));
        try std.testing.expect(eql(u8, pwd, "1234"));
        try std.testing.expect(n == null);
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
    /// Cookies to be sent
    cookies: []const Cookie = &[_]Cookie{.{ .name = "", .value = "" }},
    /// Response body sent by the server
    body: []const u8 = "",

    /// Write a simple response.
    pub fn write(s: []const u8) Response {
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
    /// Represents the Response Cookie.
    pub const Cookie = rescookie.Cookie;
};

// Run all tests, even the nested ones
test {
    std.testing.refAllDecls(@This());
}
