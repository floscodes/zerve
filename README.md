# zerve

A simple framework for writing web services in zig.

* [Create a simple Web App](#create-a-simple-web-app)
* [Types](#types)
    * [Route](#route)
    * [Handler Functions](#handler-functions)
    * [Request](#request)
        * [Get Query Params](#get-query-params)
        * [Get Header Value by Key](#get-value-of-request-header-by-key)
    * [Response](#response)
    * [Header](#header)
    * [Cookies](#cookies)
        * [Read Cookie from Request](#read-cookie-from-request)
        * [Add Cookie to Response](#add-cookie-to-response)
    * [Method](#method)
    * [HTTP-Version](#http-version)
 * [Namespaces](#namespaces)
     * [Server](#server)

# Create a simple web app

```zig
const zrv = @import("zerve"); // Or set the path to zerve.zig e.g. @import("zerve-main/src/zerve.zig");
const Request = zrv.Request;
const Response = zrv.Response;
const Server = zrv.Server;
const Route = zrv.Route;
const allocator = std.heap.page_allocator; // Choose any allocator you want!

fn index(req: *Request) Response {
    _=req;
    return Response.write("hello!");
}

fn about(req: *Request) Response {
    _=req;
    return Response.write("about site");
}

fn writeJson(req: *Request) Response {
    _=req;
    return Response.json("[1, 2, 3, 4]");
}

pub fn main() !void {
     const rt = [_]Route{.{"/", index}, .{"/about", about}, .{"/json", writeJson}};

     try Server.listen("0.0.0.0", 8080, &rt, allocator); // listens to http://localhost:8080
                                                         // http://localhost:8080/  "hello!"
                                                         // http://localhost:8080/about "about site"
                                                         // http://localhost:8080/json  "[1, 2, 3, 4]" (JSON-Response)
}
```

# Types

## Route

To write a web service with **zerve** you have to configure one or more Routes. They are being set by creating an Array of `Route`.

Example:
```zig
const rt = [_]Route{.{"/hello", helloFunction}, "/about", aboutFunction};
```
You can also set only one path and link it to a handler function, but since `Server.listen()` takes an Array of `Route` as one of it's arguments,
you have do declare it as an Array as well:
```zig
const rt = [_]Route{.{"/hello", helloFunction}};
```

## Handler Functions

Every Request is handled by a handler function. It has to be of this type: `fn(req: *Request) Response`

Example:
```zig
fn hello(req: *Request) Response {
    _ = req;
    return Response.write("hello"); // `Server` will return a Reponse with body "hello". You will see "hello" on your browser.
}
```

## Request

This represents the Request sent by the client.
```zig
pub const Request = struct {
    /// The Request Method, e.g. "GET"
    method: Method,
    /// HTTP-Version of the Request sent by the client
    httpVersion: HTTP_Version,
    /// Represents the request headers sent by the client
    headers: []const Header,
    /// The Request URI
    uri: []const u8,
    /// Represents the request body sent by the client
    body: []const u8,
};
```

### Get Query Params

**zerve** lets you easily extract query params no matter if `Request`method is `GET`or `POST`.

This can be done by using the `getQuery` method of `Request`.

Example:
```zig
fn index(req: Request) Response {

    // Assuming that a query string has been sent by the client containing the requested param,
    // e.g. `?user=james`

    const user = req.getQuery("user"); // This will return an optional
    
    if (user == null) return Response.write("") else return Response.write(user.?);
    
}
```

### Get value of Request header by key

You can get the header value of any sent header by the client with the `header`method of `Request`.

Example:

```zig
fn index(req: *Request) Response {
    
    // Get value of the 'Content-Type' header

    const h = req.header("Content-Type"); // This will return an optional

    if (h == null) return Response.write("Header not found!") else return Response.write(h.?);

}
```

## Response

A Response that is sent ny the server. Every handler function has to return a `Response`.
```zig
pub const Response = struct {
    httpVersion: HTTP_Version = HTTP_Version.HTTP1_1,
    /// Response status, default is "200 OK"
    status: stat.Status = stat.Status.OK,
    /// Response eaders sent by the server
    headers: []const Header = &[_]Header{.{ .key = "Content-Type", .value = "text/html; charset=utf-8" }},
    /// Response body sent by the server
    body: []const u8 = "",

    /// Write a simple response.
    pub fn write(s: []const u8) Response

    /// Send a response with json content.
    pub fn json(j: []const u8) Response

    /// Send a response with status not found.
    pub fn notfound(s: []const u8) Response

    /// Send a response with status forbidden.
    pub fn forbidden(s: []u8) Response
};
```

## Header

Every Request or Response has Headers represented by an Array of Headers. Every Header has a key and a value.
```zig
pub const Header = struct {
    key: []const u8,
    value: []const u8,
};
```

## Cookies

### Read Cookie from Request

To read the Cookie of a request by key, `Request` has a `cookie`-method.
It returns an optional and fetches the value of a `Request.Cookie`.

Get Request Cookie value by key:
```zig
fn index(req: *Request) Response {
    
    // Fetches the cookie value by cookie name.
    // The `cookie` method will return an optional and will be `null`
    // in case that the cookie does not exist.

    const cookie = if (req.cookie("password")) |password| password else "";

    return Response.write("cookie-test");
}
```

### Add Cookie to Response

To send a cookie in your `Response` just add a `Response.Cookie` to the `cookies` field.
The `cookies` field is a slice of `Response.Cookie`.

```zig
fn index(_: *Request) Response {

    // Define a cookie with name and value.
    // It will live for 24 hours, since `maxAge` represents
    // lifetime in seconds.
    // See all field of the `Response.Cookie` struct below.

    const cookie = Response.Cookie{.name="User", .value="James", .maxAge=60*60*24};

    var res = Response.write("Set Cookie!");
    // add cookie to the `cookies` field which is a slice of `Response.Cookie`
    res.cookies = &[_]Response.Cookie{.{cookie}};
    
    return res;
}
```

This are the fields of `Response.Cookie`:

```zig
    name: []const u8,
    value: []const u8,
    path: []const u8 = "/",
    domain: []const u8 = "",
    /// Indicates the number of seconds until the cookie expires.
    maxAge: i64 = 0,
    secure: bool = true,
    httpOnly: bool = true,
    sameSite: SameSite = .lax,
```

## Method

Represents the http method of a Request or a Response.
```zig
pub const Method = enum {
    GET,
    POST,
    PUT,
    HEAD,
    DELETE,
    CONNECT,
    OPTIONS,
    TRACE,
    PATCH,
    UNKNOWN,

    /// Turns the HTTP_method into a u8-Slice.
    pub fn stringify(m: Method) []const u8 {...}
};
```

## HTTP-Version

The HTTP-Version of a Request or a Response.
```zig
pub const HTTP_Version = enum {
    HTTP1_1,
    HTTP2,

    /// Parses from `[]u8`
    pub fn parse(s: []const u8) HTTP_Version {...}

    /// Stringifies `HTTP_Version`
    pub fn stringify(version: HTTP_Version) []const u8 {...}

};
```

# Namespaces

## Server

Server is a namespace to configure IP and Port the app will listen to by calling `Server.listen()`, as well as the routing paths (`[]Route`) it shall handle.
You can also choose an allocator that the app will use for dynamic memory allocation.
```zig
pub fn listen(ip: []const u8, port: u16, rt: []const Route, allocator: std.mem.Allocator) !void {...}
```
