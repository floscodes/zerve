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
// Function for test "Run Server"
fn handlefn(req: *types.Request) types.Response {
    // print headers of Request
    std.debug.print("\nSent headers:\n", .{});
    for (req.headers) |header| {
        std.debug.print("{s}: {s}", .{ header.key, header.value });
    }
    // print cookies of Request
    std.debug.print("\nSent cookies:\n", .{});
    for (req.cookies) |cookie| {
        std.debug.print("{s}={s}\n", .{ cookie.name, cookie.value });
    }
    var res = types.Response{ .body = "<h1>Run Server Test OK!</h1>", .cookies = &[_]Response.Cookie{.{ .name = "Test-Cookie", .value = "Test", .maxAge = 60 * 60 * 5 }} };
    return res;
}
