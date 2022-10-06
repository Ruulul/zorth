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
fn @"/modFn" (self: *Forth) anyerror!void {
    const v1 = try popStack(self);
    const v2 = try popStack(self);
    try self.stack.append(@divTrunc(v2, v1));
    try self.stack.append(@rem(v2, v1));
}
pub const @"/mod" = Core {
    .func = @"/modFn",
    .def = "( n1 n2 -- result mod )",
};
fn pickFn(self: *Forth) anyerror!void {
    const n = try popStack(self);
    const i = self.stack.items.len - @as(usize, @bitCast(u32, n));
    const nth = if (i > 0 and i <= self.stack.items.len) self.stack.items[i - 1] else return error.StackUnderflow;
    try self.stack.append(nth);
}
pub const pick = Core {
    .func = pickFn,
    .def = "( a0 .. an n -- a0 .. an a0 )",
};
fn rollFn(self: *Forth) anyerror!void {
    const n = try popStack(self);
    const i = self.stack.items.len - @as(usize, @bitCast(u32, n));
    if (i > 0 and i <= self.stack.items.len) 
        try self.stack.append(self.stack.orderedRemove(i - 1)) 
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
    try self.output.writeByte('\n');
}
pub const @"." = Core {
    .func = @".Fn",
    .def = "( n -- )",
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
fn seeFn(self: *Forth) anyerror!void {
    var tokens = std.mem.tokenize(u8, self.params, " \r\n");
    tokens.index = self.params_index.*;
    defer self.params_index.* = tokens.index;
    if (tokens.next()) |word| {
        if (self.words.get(word)) |entry| {
            try self.output.writeAll(switch (entry) {
                .core => |func| func.def,
                .word_def => |e| e,
                .variable => |v| blk: {
                    var buf: [20]u8 = undefined;
                    break :blk try std.fmt.bufPrint(&buf, "{d}", .{v});
                },
            });
            try self.output.writeByte('\n');
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

fn @".mFn"(self: *Forth) anyerror!void {
    for (self.memory.items) |item| try self.output.print("{d} ", .{item});
}
pub const @".m" = Core {
    .func = @".mFn",
    .def = "( -- )",
};
fn @".wFn"(self: *Forth) anyerror!void {
    for (self.memory.items) |item| try self.output.print("{c}", .{@bitCast(u8, @truncate(i8, item))});
}
pub const @".w" = Core {
    .func = @".wFn",
    .def = "( -- )",
};
fn @"!Fn"(self: *Forth) anyerror!void {
    const addr = try popStack(self);
    const value = try popStack(self);

    std.log.debug("addr: {any}, value: {any}",.{addr, value});
    self.memory.items[@as(usize, @bitCast(u32, addr))] = value;
}
pub const @"!" = Core {
    .func = @"!Fn",
    .def = "( value addr -- )",
};
fn @"@Fn"(self: *Forth) anyerror!void {
    const addr = try popStack(self);
    const value = self.memory.items[@as(usize, @bitCast(u32, addr))];

    try self.stack.append(value);
}
pub const @"@" = Core {
    .func = @"@Fn",
    .def = "( addr -- value )",
};
fn @"\"Fn"(self: *Forth) anyerror!void {
    const previous_delimiter = self.words.get("delimiter");
    try self.words.put("delimiter", .{ .variable = '"' });
    try parseFn(self);
    try self.words.put("delimiter", previous_delimiter orelse Forth.Entry{ .variable = ' ' });
}
pub const @"\"" = Core {
    .func = @"\"Fn",
    .def = "( -- )",
};
fn typeFn(self: *Forth) anyerror!void {
    const len = @as(usize, @bitCast(u32, try popStack(self)));
    const addr = @as(usize, @bitCast(u32, try popStack(self)));

    for (self.memory.items[addr..][0..len]) |signed| try self.output.writeByte(@bitCast(u8, @truncate(i8, signed)));
}
pub const @"type" = Core {
    .func = typeFn,
    .def = "( addr len -- )",
};
fn parseFn(self: *Forth) anyerror!void {
    const delimiter = self.words.get("delimiter") orelse Forth.Entry{ .variable = ' ' };
    self.params_index.* += 1;
    const parsing = std.mem.indexOfPos(u8, self.params, self.params_index.*, &.{ @truncate(u8, @bitCast(u32, delimiter.variable)) });

    if (parsing) |index| {
        var addr = self.memory.items.len;
        for (self.params[self.params_index.* .. index]) |byte| try self.memory.append(@as(i32, @bitCast(i8, byte)));
        try self.stack.append(@bitCast(i32, @truncate(u32, addr)));
        try self.stack.append(@bitCast(i32, @truncate(u32, index - self.params_index.*)));
        self.params_index.* = index + 1;
    } else {
        self.params_index.* = self.params.len - 1;
        try self.stack.append(-1);
        try self.stack.append(-1);
    }
}
pub const parse = Core {
    .func = parseFn,
    .def = "( -- addr len)",
};
fn variableFn(self: *Forth) anyerror!void {
    const delimiter = self.words.get("delimiter") orelse Forth.Entry{ .variable = ' '};
    const start_word = self.params_index.*;
    std.log.debug("delimiter: '{any}'", .{ delimiter });
    const end_word = std.mem.indexOfPos(u8, self.params, start_word, &.{ @truncate(u8, @bitCast(u32, delimiter.variable)), '\r', '\n' }) orelse return error.EndOfStream;

    _ = try self.memory.addOne();
    self.params_index.* = end_word + 1;

    const addr = @bitCast(i32, @truncate(u32, self.memory.items.len - 1));
    std.log.debug("word: '{s}'", .{ self.params[start_word..end_word] });
    try self.words.put(self.params[start_word..end_word], .{ .variable = addr });
    try self.stack.append(addr);
}
pub const variable = Core {
    .func = variableFn,
    .def = "",
};
fn allotFn(self: *Forth) anyerror!void {
    const n = try popStack(self);
    try self.memory.appendNTimes(0, @as(usize, @bitCast(u32, n)));
}
pub const allot = Core {
    .func = allotFn,
    .def = "( n -- )",
};
fn @",Fn"(self: *Forth) anyerror!void {
    const n = try popStack(self);
    try self.memory.append(n);
}
pub const @"," = Core {
    .func = @",Fn",
    .def = "( n -- )"
};