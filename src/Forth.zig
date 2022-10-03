const Forth = @This();
const std = @import("std");
const core = @import("core.zig");

arena: *std.heap.ArenaAllocator = undefined,
stack: StackType = undefined,
words: WordListType = undefined,
output: std.fs.File.Writer = undefined,

const StackType = std.ArrayList([]u8);
const WordListType = std.StringHashMap(Entry);
const Entry = union(enum) {
    core: *const fn (*Forth) anyerror!void,
    user_defined: []u8,
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
pub fn readInput(self: *Forth, input: []const u8) !void {
    var tokens = std.mem.tokenize(u8, input, " \r\n");
    while (tokens.next()) |token| {
        if (self.words.contains(token)) {
            try switch (self.words.get(token).?) {
                .core => |func| func(self),
                .user_defined => |def| self.readInput(def),
            };
        } else {
            try self.stack.append(try self.arena.allocator().dupe(u8, token));
        }
    }
    try self.output.writeAll("ok");
}
pub fn deinit(self: *Forth) void {
    self.stack.deinit();
    self.words.deinit();
    self.* = undefined;
}