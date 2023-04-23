const std = @import("std");
const zrv = @import("zerve.zig");
const allocator = std.heap.page_allocator;

pub fn main() !void {
    var rt = [_]zrv.Route{ .{ "/", index }, .{ "/about/", about } };

    try zrv.Server.listen("0.0.0.0", 8080, &rt, allocator);
}

fn index(req: zrv.Request) zrv.Response {
    _ = req;
    return zrv.Response.new("hello!");
}

fn about(req: zrv.Request) zrv.Response {
    _ = req;
    return zrv.Response.new("about site");
}
