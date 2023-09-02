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
    en_passent_target_square: ?types.Square,
    halfmove_clock: types.HalfmoveClock,
    fullmove_counter: types.FullmoveCounter,

    const Self = @This();

    pub fn print(self: *Self, writer: anytype) !void {
        try writer.print("{any}\n{any}\n{any}\n{any}\n{any}\n\n", .{
            self.side_to_move,
            self.castling_ability,
            self.en_passent_target_square,
            self.halfmove_clock,
            self.fullmove_counter,
        });

        inline for (.{ "rook", "pawn", "king", "knight", "bishop", "queen", "black", "white" }, .{
            self.rook_bitboard,
            self.pawn_bitboard,
            self.king_bitboard,
            self.knight_bitboard,
            self.bishop_bitboard,
            self.queen_bitboard,
            self.black_bitboard,
            self.white_bitboard,
        }) |name, board| {
            try writer.print("{s}\n", .{name});
            try writer.print("  a b c d e f g h\n", .{});
            for (0..8) |i| {
                try writer.print("{} ", .{i + 1});

                for (0..8) |j| {
                    var bit_index = ((j & 0b111) << 3) | (i & 0b111);

                    try writer.print("{s} ", .{if (board.state.isSet(bit_index)) "x" else " "});
                }
                try writer.print("\n", .{});
            }

            try writer.print("\n", .{});
        }
    }

    pub fn get_piece_board(self: *Self, comptime piece: types.PieceType) *types.Bitboard {
        return &@field(self, @tagName(piece) ++ "_bitboard");
    }
};
