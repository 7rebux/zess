const std = @import("std");

pub const N_SQUARES = 64;
pub const N_PIECES = 6;

pub const Color = enum { white, black };

pub const PieceType = enum {
    rook,
    knight,
    bishop,
    queen,
    king,
    pawn,
};

pub const Bitboard = packed struct {
    state: std.bit_set.StaticBitSet(64),

    const Self = @This();

    pub fn initEmpty() Self {
        var state = std.bit_set.StaticBitSet(64).initEmpty();
        return .{ .state = state };
    }

    pub fn get(self: *const Self, square: Square) bool {
        return self.state[@as(u6, @bitCast(square))];
    }

    pub fn set(self: *Self, square: Square, new: bool) void {
        self.state[@as(u6, @bitCast(square))] = new;
    }
};

pub const File = enum(u3) { a, b, c, d, e, f, g, h };
pub const Rank = enum(u3) { @"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8" };

pub const Square = packed struct {
    file: File,
    rank: Rank,
};

pub const HalfmoveClock = std.math.IntFittingRange(0, 50);
pub const FullmoveCounter = std.math.IntFittingRange(0, 99);

pub const Castling = packed struct {
    black_short: bool = false,
    black_long: bool = false,
    white_short: bool = false,
    white_long: bool = false,
};
