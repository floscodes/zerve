const std = @import("std");
const eql = std.mem.eql;

const types = @import("types.zig");
const Route = types.Route;
const Request = types.Request;
const Response = types.Response;

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

        while (true) {
            server.listen(addr) catch {
                server.close();
                continue;
            };
            break;
        }

        // Handling connections
        while (true) {
            const conn = if (server.accept()) |conn| conn else |_| continue;
            defer conn.stream.close();

            var buffer = std.ArrayList(u8).init(allocator);

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
            const req_stream = try buffer.toOwnedSlice();
            var req = try Request.build(req_stream);

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
                if (eql(u8, req_path, req.uri)) {
                    // If URI matches, change response with handling function.
                    res = r[1](req);
                }
            }
            // Stringify the Response and send it to the client.
            const response_string = try stringify(res, allocator);
            _ = try conn.stream.writeAll(response_string);
        }
    }
};

// Function that turns Response into a string
fn stringify(r: Response, allocator: std.mem.Allocator) ![]const u8 {
    var res = std.ArrayList(u8).init(allocator);
    try res.appendSlice(r.httpVersion.stringify());
    try res.append(' ');
    try res.appendSlice(r.status.stringify());
    try res.appendSlice("\r\n");

    for (r.headers) |header| {
        try res.appendSlice(header.stringify());
        try res.appendSlice("\n");
    }
    try res.appendSlice("\r\n\r\n");
    try res.appendSlice(r.body);

    return try res.toOwnedSlice();
}

test "stringify Response" {
    const allocator = std.heap.page_allocator;
    const headers = [_]types.Header{.{ .key = "User-Agent", .value = "Testbot" }};
    const res = Response{ .headers = &headers, .body = "This is the body!" };

    try std.testing.expect(eql(u8, try stringify(res, allocator), "HTTP/1.1 200 OK\r\nUser-Agent: Testbot\n\r\n\r\nThis is the body!"));
}
