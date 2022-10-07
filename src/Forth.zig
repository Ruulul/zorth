const Forth = @This();
const std = @import("std");
const core = @import("core.zig");

arena: *std.heap.ArenaAllocator,
stack: MainStackType,
memory: MainStackType,
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
const WordListType = std.ArrayList(Entry);
pub const Entry = struct {
    word:  []const u8,
    data: union(enum) {
    core: struct {
        def: []const u8,
        func: CoreFn,
    },
    word_def:[]const u8,
    variable: usize,
}
};
pub const Core = struct {
    func: CoreFn,
    def: []const u8,
    pub fn make(coreFn: CoreFn, defFn: []const u8) Core {
        return Core{ .func = coreFn, .def = defFn };
    }
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
    };
    inline for (@typeInfo(core).Struct.decls) |decl| {
        if (decl.is_pub)
            try self.words.append(.{ 
                .word = decl.name, 
                .data = .{ .core = .{ 
                    .def = @field(core, decl.name).def, 
                    .func = @field(core, decl.name).func 
                    }
                }
            });
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
        &.{ ' ', 
            '\r', 
            '\n', 
        });
    self.params_index = &tokens.index;
    while (tokens.next()) |token| {
        if (std.mem.eql(u8, token, ":")) {
            try self.compileWord(self.params);
            tokens.index = std.mem.indexOfPosLinear(u8, self.params, tokens.index, ";").? + 1;
        }
        else if (self.getWord(token)) |word| {
            switch (word.data) {
                .core => |func| func.func(self) catch |e| try switch (e) {
                        error.StackUnderflow => self.output.writeAll("stack underflow \n"),
                        else => self.output.print("{s} \n", .{ @errorName(e) }),
                    },
                .word_def => |word_def| try self.readInput(word_def, depth + 1),
                .variable => |index| try self.stack.append(@bitCast(i32, @truncate(u32, index))),
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

    try self.words.append(.{ 
        .word = try self.arena.allocator().dupe(u8, word), 
        .data = .{ .word_def = try self.arena.allocator().dupe(u8, def) },
    });
}
pub fn getWord(self: *Forth, word: []const u8) ?Entry {
    var i = self.words.items.len - 1;
    return while (i >= 0) {
        const entry = self.words.items[i];
        if (std.mem.eql(u8, word, entry.word)) break entry;
        if (i > 0) i -= 1 else break null;
        continue;
    };
}
pub fn deinit(self: *Forth) void {
    self.stack.deinit();
    self.words.deinit();
    self.* = undefined;
}