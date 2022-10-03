const std = @import("std");
const Forth = @import("Forth.zig");

pub fn @"+"(self: *Forth) anyerror!void {
    const v1 = try std.fmt.parseInt(u8, self.stack.popOrNull() orelse "0", 0);
    const v2 = try std.fmt.parseInt(u8, self.stack.popOrNull() orelse "0", 0);
    var buffer: [5]u8 = undefined;
    try self.stack.append(try self.arena.allocator().dupe(u8, try std.fmt.bufPrint(&buffer, "{}", .{v2 +% v1})));
}

pub fn @"-"(self: *Forth) anyerror!void {
    const v1 = try std.fmt.parseInt(u8, self.stack.popOrNull() orelse "0", 0);
    const v2 = try std.fmt.parseInt(u8, self.stack.popOrNull() orelse "0", 0);
    var buffer: [5]u8 = undefined;
    try self.stack.append(try self.arena.allocator().dupe(u8, try std.fmt.bufPrint(&buffer, "{}", .{v2 -% v1})));
}

pub fn @"*"(self: *Forth) anyerror!void {
    const v1 = try std.fmt.parseInt(u8, self.stack.popOrNull() orelse "0", 0);
    const v2 = try std.fmt.parseInt(u8, self.stack.popOrNull() orelse "0", 0);
    var buffer: [5]u8 = undefined;
    try self.stack.append(try self.arena.allocator().dupe(u8, try std.fmt.bufPrint(&buffer, "{}", .{v2 *% v1})));
}

pub fn @"/"(self: *Forth) anyerror!void {
    const v1 = try std.fmt.parseInt(u8, self.stack.popOrNull() orelse "0", 0);
    const v2 = try std.fmt.parseInt(u8, self.stack.popOrNull() orelse "0", 0);
    var buffer: [5]u8 = undefined;
    try self.stack.append(try self.arena.allocator().dupe(u8, try std.fmt.bufPrint(&buffer, "{}", .{v2 / v1})));
}

pub fn dup(self: *Forth) anyerror!void {
    const v = self.stack.popOrNull();
    if (v) |value| for ([_]void{{}} ** 2) |_| try self.stack.append(try self.arena.allocator().dupe(u8, value));
}

pub const DUP = dup;
pub fn @"."(self: *Forth) anyerror!void {
    const v = self.stack.popOrNull();
    if (v) |value| try self.output.writeAll(value);
    try self.output.writeByte('\n');
}