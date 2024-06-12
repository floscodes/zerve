const std = @import("std");
const types = @import("types.zig");
const status = @import("status.zig");
const server = @import("server.zig");

pub const Server = server.Server;
pub const Route = types.Route;
pub const Header = types.Header;
pub const Request = types.Request;
pub const Response = types.Response;
pub const Method = types.Method;
pub const HTTP_Version = types.HTTP_Version;

test "Test zerve test-app, run server and serve test page" {
    // Set route
    const rt = [_]types.Route{.{ "/", handlefn }};
    try Server.listen("0.0.0.0", 8080, &rt, std.testing.allocator);
}
// Function for test
fn handlefn(req: *types.Request) types.Response {
    const alloc = std.testing.allocator;
    // collect headers of Request
    var headers = std.ArrayList(u8).init(alloc);
    defer headers.deinit();
    for (req.headers) |header| {
        headers.appendSlice(header.key) catch {};
        headers.appendSlice(": ") catch {};
        headers.appendSlice(header.value) catch {};
        headers.appendSlice("\n") catch {};
    }
    // collect cookies of Request
    var cookies = std.ArrayList(u8).init(alloc);
    defer cookies.deinit();
    for (req.cookies) |cookie| {
        cookies.appendSlice(cookie.name) catch {};
        cookies.appendSlice(" = ") catch {};
        cookies.appendSlice(cookie.value) catch {};
        cookies.appendSlice("\n") catch {};
    }
    const res_string = std.fmt.allocPrint(alloc, "<h1>Run Server Test OK!</h1><br><h3>URI: {s}</h3><br><h3>Sent headers:</h3><br><pre><code>{s}</code></pre><br><h3>Sent Cookies:</h3><br><pre><code>{s}</code></pre><br><h3>Request body:</h3><br>{s}", .{ req.uri, headers.items, cookies.items, req.body }) catch "Memory error";
    const res = types.Response{ .body = res_string, .cookies = &[_]Response.Cookie{.{ .name = "Test-Cookie", .value = "Test", .maxAge = 60 * 3 }} };
    return res;
}
