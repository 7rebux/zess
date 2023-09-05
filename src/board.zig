const std = @import("std");
const types = @import("types.zig");

pub const Board = struct {
    rook_bitboard: types.Bitboard,
    knight_bitboard: types.Bitboard,
    bishop_bitboard: types.Bitboard,
    queen_bitboard: types.Bitboard,
    king_bitboard: types.Bitboard,
    pawn_bitboard: types.Bitboard,
    white_bitboard: types.Bitboard,
    black_bitboard: types.Bitboard,

    side_to_move: types.Color,
    castling_ability: types.Castling,
    en_passent_file: ?types.File,
    halfmove_clock: types.HalfmoveClock,
    fullmove_counter: types.FullmoveCounter,

    zobrist_hash: u64 = 0,

    const Self = @This();

    pub fn print(self: *Self, writer: anytype) !void {
        try writer.print("  a b c d e f g h\n", .{});
        for (0..8) |i| {
            try writer.print("{} ", .{i + 1});
            for (0..8) |j| {
                const bit_index = ((j & 0b111) << 3) | (i & 0b111);
                var piece_char: u8 = ' ';

                inline for (.{
                    self.rook_bitboard,
                    self.pawn_bitboard,
                    self.king_bitboard,
                    self.knight_bitboard,
                    self.bishop_bitboard,
                    self.queen_bitboard,
                }, .{ 'r', 'p', 'k', 'n', 'b', 'q' }) |board, char| {
                    if (board.state.isSet(bit_index)) {
                        piece_char = if (self.white_bitboard.state.isSet(bit_index)) std.ascii.toUpper(char) else char;
                        break;
                    }
                }
                try writer.print("{c} ", .{piece_char});
            }
            try writer.print("\n", .{});
        }
    }

    pub fn get_piece_board(self: *Self, comptime piece: types.PieceType) *types.Bitboard {
        return &@field(self, @tagName(piece) ++ "_bitboard");
    }
};
