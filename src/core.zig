const std = @import("std");
const Forth = @import("Forth.zig");

fn popStack(self: *Forth) error{StackUnderflow}!i32 {
    return self.stack.popOrNull() orelse error.StackUnderflow;
}
pub fn @"="(self: *Forth) anyerror!void {
    const v1 = try popStack(self);
    const v2 = try popStack(self);
    try self.stack.append(@boolToInt(v1 == v2));
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
    try self.output.writeByte('\n');
}
pub const EMIT = emit;
