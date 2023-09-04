const std = @import("std");
const fen = @import("fen.zig");
const zobrist = @import("zobrist.zig");

test "root" {
    std.testing.refAllDecls(fen);
}

pub fn main() !void {
    try std.io.getStdOut().writeAll("\n");

    // Setup things
    zobrist.init();

    var board = try fen.parse("rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2");

    try board.print(std.io.getStdOut().writer());
    try fen.write(&board, std.io.getStdOut().writer());
}
