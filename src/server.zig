const std = @import("std");
const allocator = std.heap.page_allocator;
const eql = std.mem.eql;

const types = @import("types.zig");
const Route = types.Route;
const Request = types.Request;
const Response = types.Response;

pub const Server = struct {
    pub fn listen(ip: []const u8, port: u16, rt: []const Route) !void {

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
            // Building the Request
            const req_stream = try buffer.toOwnedSlice();
            const req = try Request.build(req_stream);

            std.debug.print("Request sent by client:\n{s}", .{buffer.items});

            for (rt) |r| {
                if (eql(u8, r[0], req.uri)) {
                    _ = r[1](req);
                    break;
                }
            }

            _ = try conn.stream.write("HTTP/1.1 200 OK\r\n");
            _ = try conn.stream.write("Content-Type: text/html\r\n\r\n");
            _ = try conn.stream.write("<h1>It works!</h1>");
        }
    }
};
