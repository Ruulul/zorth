const std = @import("std");
const Forth = @import("Forth.zig");
const Core = Forth.Core;

fn popStack(self: *Forth) error{StackUnderflow}!i32 {
    return self.stack.popOrNull() orelse error.StackUnderflow;
}
inline fn boolToInt(ok: bool) i32 {
    return @as(i32, @boolToInt(ok)) * -1;
}
fn @"=Fn"(self: *Forth) anyerror!void {
    const v1 = try popStack(self);
    const v2 = try popStack(self);
    try self.stack.append(boolToInt(v2 == v1));
}
pub const @"=" = Core {
    .func = @"=Fn",
    .def = "( n1 n2 -- n1=n2 )",
};
fn @">Fn" (self: *Forth) anyerror!void {
    const v1 = try popStack(self);
    const v2 = try popStack(self);
    try self.stack.append(boolToInt(v2 > v1));
}
pub const @">" = Core {
    .func = @">Fn",
    .def = "( n1 n2 -- n1>n2 )",
};
fn @"<Fn" (self: *Forth) anyerror!void {
    const v1 = try popStack(self);
    const v2 = try popStack(self);
    try self.stack.append(boolToInt(v2 < v1));
}
pub const @"<" = Core {
    .func = @"<Fn",
    .def = "( n1 n2 -- n1<n2 )",
};
fn @"+Fn" (self: *Forth) anyerror!void {
    const v1 = try popStack(self);
    const v2 = try popStack(self);
    try self.stack.append(v2 + v1);
}
pub const @"+" = Core {
    .func = @"+Fn",
    .def = "( n1 n2 -- n1+n2 )",
};
fn @"-Fn" (self: *Forth) anyerror!void {
    const v1 = try popStack(self);
    const v2 = try popStack(self);
    try self.stack.append(v2 - v1);
}
pub const @"-" = Core {
    .func = @"-Fn",
    .def = "( n1 n2 -- n1-n2 )",
};
fn @"*Fn" (self: *Forth) anyerror!void {
    const v1 = try popStack(self);
    const v2 = try popStack(self);
    try self.stack.append(v2 * v1);
}
pub const @"*" = Core {
    .func = @"*Fn",
    .def = "( n1 n2 -- n1*n2 )",
};
// TODO: replace with /MOD
fn @"/Fn" (self: *Forth) anyerror!void {
    const v1 = try popStack(self);
    const v2 = try popStack(self);
    try self.stack.append(@divTrunc(v2, v1));
}
pub const @"/" = Core {
    .func = @"/Fn",
    .def = "( n1 n2 -- n1/n2 )",
};
fn pickFn(self: *Forth) anyerror!void {
    const n = try popStack(self);
    const i = self.stack.items.len - @as(usize, @bitCast(u32, n)) - 1;
    const nth = if (i >= 0 and i < self.stack.items.len) self.stack.items[i] else return error.StackUnderflow;
    try self.stack.append(nth);
}
pub const pick = Core {
    .func = pickFn,
    .def = "( a0 .. an n -- a0 .. an a0 )",
};
fn rollFn(self: *Forth) anyerror!void {
    const n = try popStack(self);
    const i = self.stack.items.len - @as(usize, @bitCast(u32, n)) - 1;
    if (i >= 0 and i < self.stack.items.len) 
        try self.stack.append(self.stack.orderedRemove(i)) 
    else return error.StackUnderflow;
}
pub const roll = Core {
    .func = rollFn,
    .def = "( a0 .. an n -- a1 .. an a0 )",
};
fn dropFn(self: *Forth) anyerror!void {
    _ = try popStack(self);
}
pub const drop = Core {
    .func = dropFn,
    .def = "( n -- )",
};
fn @".Fn"(self: *Forth) anyerror!void {
    const value = try popStack(self);
    try std.fmt.formatInt(value, 10, .upper, .{}, self.output);
    try cr.func(self);
}
pub const @"." = Core {
    .func = @".Fn",
    .def = "( n -- )",
};
fn crFn(self: *Forth) anyerror!void {
    try self.output.writeByte('\n');
}
pub const cr = Core {
    .func = crFn,
    .def = "( -- )",
};
//TODO: Better char handling
fn emitFn(self: *Forth) anyerror!void {
    const value = try popStack(self);
    try std.fmt.formatIntValue(@truncate(u8, @bitCast(u32, value)), "c", .{}, self.output);
}
pub const emit = Core {
    .func = emitFn,
    .def = "( c -- )",
};
fn @"(Fn"(self: *Forth) anyerror!void {
    if (std.mem.indexOfPos(u8, self.params, self.params_index.*, ")")) |new_index| self.params_index.* = new_index + 1;
}
pub const @"(" = Core {
    .func = @"(Fn",
    .def = "( -- )",
};
fn seeFn(self: *Forth) anyerror!void {
    var tokens = std.mem.tokenize(u8, self.params, " \r\n");
    tokens.index = self.params_index.*;
    defer self.params_index.* = tokens.index;
    if (tokens.next()) |word| {
        if (self.words.get(word)) |entry| {
            try self.output.writeAll(switch (entry) {
                .core => |func| func.def,
                .user_defined => |e| e,
            });
            try cr.func(self);
        } else try self.output.print("{s} ?", .{word});
    }
}
pub const see = Core {
    .func = seeFn,
    .def = "( -- )",
};

fn @".sFn"(self: *Forth) anyerror!void {
    for (self.stack.items) |item| try self.output.print("{d} ", .{item});
}
pub const @".s" = Core {
    .func = @".sFn",
    .def = "( -- )",
};