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
};

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

    fn build(bytes: []u8) Request {
        const lines = std.mem.split(u8, bytes, "\n");
        var req: Request = undefined;
        var header_buffer = std.ArrayList(Header).init(allocator);
        defer header_buffer.deinit();

        for (lines, 0..) |line, index| {
            if (index == 0) {
                const items = std.mem.split(u8, line, " ");
                req.method = items[0];
                req.uri = items[1];
                continue;
            }
            var item = std.mem.split(u8, line, ":");
            const header = Header{ .key = std.mem.trim(u8, item[0], " "), .value = std.mem.trim(u8, item[1], " ") };
            try header_buffer.append(header);
        }
        req.headers = header_buffer.items;
        return req;
    }
};

/// Represents a standard http-Response sent by the webapp (server).
/// It is the return type of every handling function.
pub const Response = struct {
    /// Response status, default is "200 OK"
    status: stat.Status = stat.Status.OK,
    /// Response eaders sent by the server
    headers: []const Header = &[_]Header{.{ .key = "Content-Type", .value = "text/html; charset=utf-8" }},
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
};

pub const Server = struct {
    pub fn listen(ip: []const u8, port: u16, rt: []const Route) !void {
        _ = rt;

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
            // Building the Request
            // TODO write Request building!

            // TODO: Write the loop to handle the requests!
            // TODO: Create Response!
            _ = try conn.stream.write("HTTP/1.1 200 OK\r\n");
            _ = try conn.stream.write("Content-Type: text/html\r\n\r\n");
            _ = try conn.stream.write("<h1>It works!</h1>");
        }
    }
};
