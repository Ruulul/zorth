const Forth = @This();
const std = @import("std");
const core = @import("core.zig");

arena: *std.heap.ArenaAllocator = undefined,
stack: StackType = undefined,
words: WordListType = undefined,
output: std.fs.File.Writer = undefined,

const StackType = std.ArrayList(i32);
const WordListType = std.StringHashMap(Entry);
const Entry = union(enum) {
    core: *const fn (*Forth) anyerror!void,
    user_defined: []const u8,
};

pub fn init(arena: *std.heap.ArenaAllocator, output: std.fs.File.Writer) !Forth {
    var self = Forth{};
    self.arena = arena;
    self.output = output;
    self.stack = StackType.init(arena.allocator());
    self.words = WordListType.init(arena.allocator());
    inline for (@typeInfo(core).Struct.decls) |decl| {
        if (decl.is_pub)
            try self.words.put(decl.name, .{ .core = @field(core, decl.name) });
    }
    return self;
}
pub fn readInput(self: *Forth, input: []const u8, depth: usize) !void {
    if (depth > 100) {
        try self.output.writeAll("\nToo much recursion!\nExiting...");
        return error.TooMuchRecursion;
    }
    var tokens = std.mem.tokenize(u8, input, " \r\n");
    while (tokens.next()) |token| {
        if (std.mem.eql(u8, token, ":")) {
            try self.compileWord(input);
            tokens.index = std.mem.indexOfPos(u8, input, tokens.index, ";").?;
        }
        else if (self.words.contains(token)) {
            switch (self.words.get(token).?) {
                .core => |func| func(self) catch |e| switch (e) {
                        error.StackUnderflow => {
                            try self.output.writeAll("stack underflow \n");
                        },
                        else => try self.output.writeAll(@errorName(e))
                    },
                .user_defined => |def| try self.readInput(def, depth + 1),
            }
        } else {
            var number = std.fmt.parseInt(i32, token, 0) catch { try self.output.print(" {s} ?\n", .{token}); continue; };
            try self.stack.append(number);
        }
    }
    if (depth == 0) try self.output.writeAll("ok");
}
pub fn compileWord(self: *Forth, input: []const u8) !void {
    const start_of_word = std.mem.indexOfPos(u8, input, 0, ":").? + 2;
    const end_of_word = std.mem.indexOfPos(u8, input, start_of_word, " ").?;
    const word = input[start_of_word..end_of_word];

    const start_of_def = end_of_word + 1;
    const end_of_def = std.mem.indexOfPos(u8, input, start_of_def, ";").?;
    const def = input[start_of_def..end_of_def];

    try self.words.put(try self.arena.allocator().dupe(u8, word), .{ .user_defined = try self.arena.allocator().dupe(u8, def) });
}
pub fn deinit(self: *Forth) void {
    self.stack.deinit();
    self.words.deinit();
    self.* = undefined;
}