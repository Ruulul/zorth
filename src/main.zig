const std = @import("std");
const Forth = @import("Forth.zig");

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