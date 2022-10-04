const std = @import("std");
const Forth = @import("Forth.zig");

fn popStack(self: *Forth) error{StackUnderflow}!i32 {
    return self.stack.popOrNull() orelse error.StackUnderflow;
}
inline fn boolToInt(ok: bool) i32 {
    return @as(i32, @boolToInt(ok)) * -1;
}
pub fn @"="(self: *Forth) anyerror!void {
    const v1 = try popStack(self);
    const v2 = try popStack(self);
    try self.stack.append(boolToInt(v2 == v1));
}
pub fn @">"(self: *Forth) anyerror!void {
    const v1 = try popStack(self);
    const v2 = try popStack(self);
    try self.stack.append(boolToInt(v2 > v1));
}
pub fn @"<"(self: *Forth) anyerror!void {
    const v1 = try popStack(self);
    const v2 = try popStack(self);
    try self.stack.append(boolToInt(v2 < v1));
}
pub fn @"+"(self: *Forth) anyerror!void {
    const v1 = try popStack(self);
    const v2 = try popStack(self);
    try self.stack.append(v2 + v1);
}
pub fn @"-"(self: *Forth) anyerror!void {
    const v1 = try popStack(self);
    const v2 = try popStack(self);
    try self.stack.append(v2 - v1);
}
pub fn @"*"(self: *Forth) anyerror!void {
    const v1 = try popStack(self);
    const v2 = try popStack(self);
    try self.stack.append(v2 * v1);
}
pub fn @"/"(self: *Forth) anyerror!void {
    const v1 = try popStack(self);
    const v2 = try popStack(self);
    try self.stack.append(@divTrunc(v2, v1));
}
pub fn dup(self: *Forth) anyerror!void {
    const value = try popStack(self);
    for ([_]void{{}} ** 2) |_| try self.stack.append(value);
}
pub const DUP = dup;
pub fn drop(self: *Forth) anyerror!void {
    _ = try popStack(self);
}
pub const DROP = drop;
pub fn @"."(self: *Forth) anyerror!void {
    const value = try popStack(self);
    try std.fmt.formatInt(value, 10, .upper, .{}, self.output);
    try self.output.writeByte('\n');
}
//TODO: Better char handling
pub fn emit(self: *Forth) anyerror!void {
    const value = try popStack(self);
    try std.fmt.formatIntValue(@truncate(u8, @bitCast(u32, value)), "c", .{}, self.output);
}
pub const EMIT = emit;
pub fn @"("(self: *Forth) anyerror!void {
    if (std.mem.indexOfPos(u8, self.params, self.params_index.*, ")")) |new_index| self.params_index.* = new_index + 1;
}
pub fn see(self: *Forth) anyerror!void {
    var tokens = std.mem.tokenize(u8, self.params, " \r\n");
    tokens.index = self.params_index.*;
    defer self.params_index.* = tokens.index;
    if (tokens.next()) |word| {
        if (self.words.get(word)) |entry| {
            try self.output.writeAll(switch (entry) {
                .core => "Cant see core definitions",
                .user_defined => |e| e,
            });
        } else try self.output.print("{s} ?", .{word});
    }
}
pub const SEE = see;