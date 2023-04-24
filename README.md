# zerve
A simple framework for writing web services in zig.

## Create a simple web app

```zig
const zrv = @import("zerve");
const Request = zrv.Request;
const Response = zrv.Response;
const Server = zrv.Server;
const Route = zrv.Route;
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

     try Server.listen("0.0.0.0", 8080, &rt, allocator); // listens to http://localhost:8080
                                                         // http://localhost:8080/  "hello!"
                                                         // http://localhost:8080/about "about site"
                                                         // http://localhost:8080/json  "[1, 2, 3, 4]" (JSON-Response)
}

```
