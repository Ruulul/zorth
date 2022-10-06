const Forth = @This();
const std = @import("std");
const core = @import("core.zig");

arena: *std.heap.ArenaAllocator,
stack: MainStackType,
memory: MainStackType,
string_stack: std.ArrayList(u8),
params: []const u8 = undefined,
params_index: *usize = undefined,
words: WordListType,
output: std.fs.File.Writer,
max_depth: usize = 100,

mode: Mode = .interpreter,

const Mode = enum {
    compiler,
    interpreter,
};
const MainStackType = std.ArrayList(i32);
const WordListType = std.StringHashMap(Entry);
pub const Entry = union(enum) {
    core: Core,
    word_def: []const u8,
    variable: i32,
};
pub const Core = struct {
    func: *const fn (*Forth) anyerror!void,
    def: []const u8,
};
pub const CoreFn = *const fn (*Forth) anyerror!void;
const compiler = @embedFile("compiler.f");
pub fn init(arena: *std.heap.ArenaAllocator, output: std.fs.File.Writer) !Forth {
    var self = Forth{ 
        .arena = arena, 
        .output = output, 
        .stack = MainStackType.init(arena.allocator()), 
        .words = WordListType.init(arena.allocator()),
        .memory = MainStackType.init(arena.allocator()),
        .string_stack = std.ArrayList(u8).init(arena.allocator()),
    };
    inline for (@typeInfo(core).Struct.decls) |decl| {
        if (decl.is_pub)
            try self.words.put(decl.name, .{ .core = @field(core, decl.name) });
    }
    var lines = std.mem.tokenize(u8, compiler, "\n\r");
    while (lines.next()) |line| try self.readInput(line, 1);
    return self;
}
pub fn readInput(self: *Forth, input: []const u8, depth: usize) !void {
    if (depth > self.max_depth) {
        try self.output.writeAll("\nToo much recursion!\nExiting...");
        return error.TooMuchRecursion;
    }

    self.params = try std.ascii.allocLowerString(self.arena.allocator(), input);
    defer self.arena.allocator().free(self.params);

    var tokens = std.mem.tokenize(u8, 
        self.params, 
        &.{ 
            @truncate(u8, @bitCast(u32, (' '))), 
            '\r', 
            '\n', 
        });
    self.params_index = &tokens.index;
    while (tokens.next()) |token| {
        if (std.mem.eql(u8, token, ":")) {
            try self.compileWord(self.params);
            tokens.index = std.mem.indexOfPosLinear(u8, self.params, tokens.index, ";").? + 1;
        }
        else if (self.words.contains(token)) {
            switch (self.words.get(token).?) {
                .core => |func| func.func(self) catch |e| try switch (e) {
                        error.StackUnderflow => self.output.writeAll("stack underflow \n"),
                        else => self.output.writeAll(@errorName(e))
                    },
                .word_def => |def| try self.readInput(def, depth + 1),
                .variable => |index| try self.stack.append(index),
            }
        } else {
            var number = std.fmt.parseInt(i32, token, 0) catch { try self.output.print(" {s} ?\n", .{token}); continue; };
            try self.stack.append(number);
        }
    }
    if (depth == 0) try self.output.writeAll("\nok");
}
pub fn compileWord(self: *Forth, input: []const u8) !void {
    const start_of_word = std.mem.indexOfPosLinear(u8, input, 0, ":").? + 2;
    const end_of_word = std.mem.indexOfPosLinear(u8, input, start_of_word, " ").?;
    const word = input[start_of_word..end_of_word];

    const start_of_def = end_of_word + 1;
    const end_of_def = std.mem.indexOfPosLinear(u8, input, start_of_def, ";").?;
    const def = input[start_of_def..end_of_def];

    try self.words.put(try self.arena.allocator().dupe(u8, word), .{ .word_def = try self.arena.allocator().dupe(u8, def) });
}
pub fn deinit(self: *Forth) void {
    self.stack.deinit();
    self.words.deinit();
    self.* = undefined;
}