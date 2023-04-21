const std = @import("std");
const zrv = @import("zerve.zig");

pub fn main() !void {
    var rt = [_]zrv.Route{.{ "/", index }};

    try zrv.Server.listen("0.0.0.0", 8080, &rt);
}

fn index(req: zrv.Request) zrv.Response {
    _ = req;
    return zrv.Response.write("hello!");
}
