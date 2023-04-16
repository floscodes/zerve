const std = @import("std");
const status = @import("status.zig");

const allocator = std.heap.page_allocator;

pub fn main() !void {

    // Init server
    const server_options: std.net.StreamServer.Options = .{};
    var server = std.net.StreamServer.init(server_options);
    defer server.deinit();
    const addr = try std.net.Address.parseIp("0.0.0.0", 8080);

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
        std.debug.print("Data sent by the client:\n{s}\n", .{buffer.items});
        // Creating Response
        _ = try conn.stream.write("HTTP/1.1 200 OK\r\n");
        _ = try conn.stream.write("Content-Type: text/html\r\n\r\n");
        _ = try conn.stream.write("<h1>It works!</h1>");
    }
}
