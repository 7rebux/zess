const std = @import("std");
const fen = @import("fen.zig");
const zobrist = @import("zobrist.zig");

test "root" {
    std.testing.refAllDecls(fen);
}

pub fn main() !void {
    const fen_string = "rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2";

    std.debug.print("{s}\n\n", .{fen_string});

    var board = try fen.parse(fen_string);

    try board.print(std.io.getStdOut().writer());
    try fen.write(&board, std.io.getStdOut().writer());

    std.debug.print("\nHash: {}", .{board.zobrist_hash});
}
