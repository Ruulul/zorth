const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var forth = Forth.init(allocator);
    defer forth.deinit();

    if (args.len < 2) {
        std.log.info("Init in cli mode.", .{});
        const stdin = std.io.getStdIn().reader();
        const stdout = std.io.getStdOut().writer();

        while (true) {
            try stdout.writeAll("\n|> ");
            var buffer: [256]u8 = undefined;
            const input = try stdin.readUntilDelimiter(&buffer, '\n');
            var tokens = std.mem.tokenize(u8, input, " \r\n");
            while (tokens.next()) |token| try forth.stack.append(try allocator.dupe(u8, token));
            try stdout.writeAll("The Stack right now: "); 
            for (forth.stack.items) |item| try stdout.print("{s} ", .{item});
            try stdout.writeAll("\nThe WordList right now: "); 
            var words = forth.words.keyIterator();
            while (words.next()) |item| try stdout.print("{s} ", .{item});
        }
    }
    else {
        std.log.info("Gotta filename {s}, lets run.", .{args[1]});
    }
}

const Forth = struct {
    allocator: std.mem.Allocator = undefined,
    stack: StackType = undefined,
    words: std.StringHashMap([]u8) = undefined,
    const StackType = std.ArrayList([]u8);
    const WordListType = std.StringHashMap(Entry);
    const Entry = union {
        core: * fn (Forth) void,
        user_defined: []u8,
    };
    pub fn init(allocator: std.mem.Allocator) Forth {
        var self = Forth{};
        self.allocator = allocator;
        self.stack = StackType.init(allocator);
        self.words = WordListType.init(allocator);
        try self.words.put("+", .{ .core = core.sum });
        return self;
    }
    pub fn deinit(self: *Forth) void {
        for (self.stack.items) |item| self.stack.allocator.free(item);
        self.stack.deinit();
        var words = self.words.iterator();
        while (words.next()) |word| self.stack.allocator.free(word);
        self.words.deinit();
        self.* = undefined;
    }

    const core = struct {
        pub fn sum(self: Forth) void {
                _ = self.stack.pop();

                var v1 = try std.fmt.parseInt(u8, self.stack.pop(), 0);
                var v2 = try std.fmt.parseInt(u8, self.stack.pop(), 0);

                self.stack.append(v1 + v2);
            }
    };
};