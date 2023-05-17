const std = @import("std");
pub const io_mode: std.io.Mode = .evented;
const olderVersion: bool = @import("builtin").zig_version.minor < 11;
const eql = std.mem.eql;

const types = @import("types.zig");
const Route = types.Route;
const Request = types.Request;
const Response = types.Response;
const Header = types.Header;
const Method = types.Method;
const HTTP_Version = types.HTTP_Version;

/// Server is a namespace to configure IP and Port the app will listen to, as well as
/// the routing paths (`[]Route`) it shall handle.
/// You can also choose an allocator that the app will use for dynamic memory allocation.
pub const Server = struct {
    pub fn listen(ip: []const u8, port: u16, rt: []const Route, allocator: std.mem.Allocator) !void {

        // Init server
        const server_options: std.net.StreamServer.Options = .{};
        var server = std.net.StreamServer.init(server_options);
        defer server.deinit();
        const addr = try std.net.Address.parseIp(ip, port);

        try server.listen(addr);

        // Handling connections
        while (true) {
            const conn = if (server.accept()) |conn| conn else |_| continue;
            defer conn.stream.close();

            const client_ip = try std.fmt.allocPrint(allocator, "{}", .{conn.address});
            defer allocator.free(client_ip);

            var buffer = std.ArrayList(u8).init(allocator);
            defer buffer.deinit();

            var chunk_buf: [4096]u8 = undefined;
            // Collect max 4096 bytes of data from the stream into the chunk_buf. Then add it
            // to the ArrayList. Repeat this until request stream ends by counting the appearence
            // of "\r\n"
            while (true) {
                _ = try conn.stream.read(chunk_buf[0..]);
                try buffer.appendSlice(chunk_buf[0..]);
                if (std.mem.containsAtLeast(u8, buffer.items, 2, "\r\n")) break;
            }
            // Build the Request
            const req_stream = if (olderVersion) buffer.toOwnedSlice() else try buffer.toOwnedSlice();
            defer allocator.free(req_stream);
            var req = try buildRequest(client_ip, req_stream, allocator);
            defer allocator.free(req.headers);
            defer allocator.free(req.cookies);

            // if there ist a path set in the uri trim the trailing slash in order to accept it later during the matching check.
            if (req.uri.len > 1) req.uri = std.mem.trimRight(u8, req.uri, "/");

            // Building the response
            // First initialize a notfound Response that is being changed if a Route path matches with Request URI.
            var res = Response.notfound("");

            // Do the matching check. Iterate over the Routes and change the Response being sent in case of matching.
            for (rt) |r| {
                var req_path = r[0];
                // Trim a possible trailing slash from Route path in order to accept it during the matching process.
                if (req_path.len > 1) req_path = std.mem.trimRight(u8, req_path, "/");
                // Check if there is a match
                if (eql(u8, req_path, req.uri)) {
                    // Change response with handling function in case of match.
                    res = r[1](&req);
                    // Exit loop in case of match
                    break;
                }
            }
            // Stringify the Response.
            const response_string = try stringifyResponse(res, allocator);
            // Free memory after writing Response and sending it to client.
            defer allocator.free(response_string);
            // Write stringified Response and send it to client.
            _ = try conn.stream.write(response_string);
        }
    }
};

// Function that build the request from stream
fn buildRequest(client_ip: []const u8, bytes: []const u8, allocator: std.mem.Allocator) !Request {
    var req: Request = undefined;
    req.ip = client_ip;
    var parts = std.mem.split(u8, bytes, "\r\n");
    const header = parts.first();
    var header_lines = std.mem.split(u8, header, "\n");
    var header_buffer = std.ArrayList(Header).init(allocator);
    var cookie_buffer = std.ArrayList(Request.Cookie).init(allocator);

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
        // Check if header is a cookie and parse it
        if (eql(u8, item1, "Cookie") or eql(u8, item1, "cookie")) {
            const item2 = if (headers.next()) |value| value else "";
            const cookies = try Request.Cookie.parse(item2, allocator);
            defer allocator.free(cookies);
            try cookie_buffer.appendSlice(cookies);
            continue;
        }
        const item2 = if (headers.next()) |value| value else "";
        const header_pair = Header{ .key = item1, .value = item2 };
        try header_buffer.append(header_pair);
    }
    req.cookies = if (olderVersion) cookie_buffer.toOwnedSlice() else try cookie_buffer.toOwnedSlice();
    req.headers = if (olderVersion) header_buffer.toOwnedSlice() else try header_buffer.toOwnedSlice();
    req.body = if (parts.next()) |value| value else "";
    return req;
}

// Test the Request build function
test "build a Request" {
    const bytes = "GET /test HTTP/1.1\nHost: localhost:8080\nUser-Agent: Testbot\r\nThis is the test body!";
    const allocator = std.testing.allocator;
    const client_ip = "127.0.0.1";
    const req = try buildRequest(client_ip, bytes, allocator);
    defer allocator.free(req.headers);
    try std.testing.expect(req.method == Method.GET);
    try std.testing.expect(req.httpVersion == HTTP_Version.HTTP1_1);
    try std.testing.expect(std.mem.eql(u8, req.uri, "/test"));
    try std.testing.expect(std.mem.eql(u8, req.headers[1].key, "User-Agent"));
    try std.testing.expect(std.mem.eql(u8, req.headers[1].value, "Testbot"));
    try std.testing.expect(std.mem.eql(u8, req.headers[0].key, "Host"));
    try std.testing.expect(std.mem.eql(u8, req.headers[0].value, "localhost:8080"));
    try std.testing.expect(std.mem.eql(u8, req.body, "This is the test body!"));
}

// Function that turns Response into a string
fn stringifyResponse(r: Response, allocator: std.mem.Allocator) ![]const u8 {
    var res = std.ArrayList(u8).init(allocator);
    try res.appendSlice(r.httpVersion.stringify());
    try res.append(' ');
    try res.appendSlice(r.status.stringify());
    try res.appendSlice("\r\n");
    // Add headers
    for (r.headers) |header| {
        try res.appendSlice(header.key);
        try res.appendSlice(": ");
        try res.appendSlice(header.value);
        try res.appendSlice("\n");
    }
    // Add cookie-headers
    for (r.cookies) |cookie| {
        const c = try cookie.stringify(allocator);
        defer allocator.free(c);
        if (!eql(u8, cookie.name, "") and !eql(u8, cookie.value, "")) try res.appendSlice(c);
    }
    try res.appendSlice("\r\n\r\n");
    try res.appendSlice(r.body);

    return if (olderVersion) res.toOwnedSlice() else try res.toOwnedSlice();
}

test "stringify Response" {
    const allocator = std.testing.allocator;
    const headers = [_]types.Header{.{ .key = "User-Agent", .value = "Testbot" }};
    const res = Response{ .headers = &headers, .body = "This is the body!" };
    const res_str = try stringifyResponse(res, allocator);
    defer allocator.free(res_str);
    try std.testing.expect(eql(u8, res_str, "HTTP/1.1 200 OK\r\nUser-Agent: Testbot\n\r\n\r\nThis is the body!"));
}
