# zerve
A simple framework for writing web services in zig.

## Create a simple web app

```zig
usingnamespace @import("zerve");
const allocator = std.heap.page_allocator;

fn index(req: Request) Response {
    _=req;
    return Response.new("hello!");
}

fn about(req: Request) Response {
    _=req;
    return Response.new("about site");
}

fn writeJson(req: Request) Response {
    _=req;
    Response.json("[1, 2, 3, 4]");
}

pub fn main() !void {
     const rt = [_]Route{.{"/", index}, .{"/about", about}, .{"/json", writeJson}};

     try Server.listen("0.0.0.0", 8080, &rt, allocator);
}

```