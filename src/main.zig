const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const inner_allocator = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(inner_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    if (args.len < 2) {
        std.log.info("Init in cli mode.", .{});

        var forth = try Forth.init(&arena, stdout);
        defer forth.deinit();

        while (true) {
            try stdout.writeAll("\n|> ");
            var buffer: [256]u8 = undefined;
            const input = try stdin.readUntilDelimiter(&buffer, '\n');
            try forth.readInput(input);
        }
    }
    else {
        std.log.info("Gotta filename {s}, lets run.", .{args[1]});
        const entry = std.fs.cwd().openFile(args[1], .{}) catch {
            try stdout.writeAll("The path insert is invalid.");
            return;
        };
        defer entry.close();

        var forth = try Forth.init(&arena, stdout);
        defer forth.deinit();
        
        const input = try entry.readToEndAlloc(allocator, 1024 * 1024 * 300);
        var lines = std.mem.tokenize(u8, input, "\n\r;");
        while (lines.next()) |line| try forth.readInput(line);
    }
}

const Forth = struct {
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
        try self.output.writeAll("\nok");
    }
    pub fn deinit(self: *Forth) void {
        self.stack.deinit();
        self.words.deinit();
        self.* = undefined;
    }

    const core = struct {
        pub fn @"+"(self: *Forth) anyerror!void {
            const v1 = try std.fmt.parseInt(u8, self.stack.popOrNull() orelse "0", 0);
            const v2 = try std.fmt.parseInt(u8, self.stack.popOrNull() orelse "0", 0);
            var buffer: [5]u8 = undefined;

            try self.stack.append(try self.arena.allocator().dupe(u8, try std.fmt.bufPrint(&buffer, "{}", .{v1 +% v2})));
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
        const DUP = dup;
        pub fn @"."(self: *Forth) anyerror!void {
            const v = self.stack.popOrNull();
            if (v) |value| try self.output.writeAll(value);
        }
    };
};