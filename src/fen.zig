/// Forsyth-Edwards Notation
/// https://www.chessprogramming.org/Forsyth-Edwards_Notation
/// <Piece Placement> <Side to move> <Castling ability> <En passsant target square> <Halfmove clock> <Fullmove counter>
const std = @import("std");
const types = @import("types.zig");
const Board = @import("board.zig").Board;

const FenError = error{
    TooManyParts,
    NotEnoughParts,
    InvalidPiecesPlacement,
    InvalidSideToMove,
    InvalidEnPassentSquare,
    InvalidHalfmoveClock,
    InvalidFullmoveCounter,
    InvalidCastlingAbility,
};

pub fn parse(fen: []const u8) FenError!Board {
    var board: Board = undefined;
    var parts_it = std.mem.split(u8, fen, " ");
    var parts: [6][]const u8 = undefined;
    var i: u8 = 0;

    while (parts_it.next()) |part| : (i += 1) {
        if (i > 5) {
            std.log.err("FEN: {s}", .{fen});
            return FenError.TooManyParts;
        }

        parts[i] = part;
    }

    if (i < 5) {
        std.log.err("FEN: {s}", .{fen});
        return FenError.NotEnoughParts;
    }

    try parse_pieces(&board, parts[0]);
    try parse_side_to_move(&board, parts[1]);
    try parse_castling_ability(&board, parts[2]);
    try parse_en_passent_target_square(&board, parts[3]);
    try parse_halfmove_clock(&board, parts[4]);
    try parse_fullmove_counter(&board, parts[5]);

    return board;
}

/// The Piece Placement is determined rank by rank in big-endian order,
/// that is starting at the 8th rank down to the first rank.
/// Each rank is separated by the terminal symbol '/' (slash).
/// One rank, scans piece placement in little-endian file-order from the A to H.
/// A decimal digit counts consecutive empty squares,
/// the pieces are identified by a single letter from standard English names for chess pieces
/// as used in the Algebraic Chess Notation.
/// Uppercase letters are for white pieces, lowercase letters for black pieces.
pub fn parse_pieces(board: *Board, part: []const u8) FenError!void {
    var i: u8 = 0;
    var ranks_it = std.mem.splitBackwards(u8, part, "/");

    board.rook_bitboard = types.Bitboard.initEmpty();
    board.knight_bitboard = types.Bitboard.initEmpty();
    board.bishop_bitboard = types.Bitboard.initEmpty();
    board.queen_bitboard = types.Bitboard.initEmpty();
    board.king_bitboard = types.Bitboard.initEmpty();
    board.pawn_bitboard = types.Bitboard.initEmpty();
    board.white_bitboard = types.Bitboard.initEmpty();
    board.black_bitboard = types.Bitboard.initEmpty();

    while (ranks_it.next()) |rank| : (i += 1) {
        var j: u8 = 0;

        if (i > 7) {
            std.log.err("pieces: {s}", .{part});
            return FenError.InvalidPiecesPlacement;
        }

        for (rank) |x| {
            var bit_index = ((j & 0b111) << 3) | (i & 0b111);

            switch (x) {
                inline '1'...'8' => |inc| {
                    const val = comptime std.fmt.parseInt(u4, &.{inc}, 10) catch unreachable;
                    j += val;
                    if (j >= 8) break;
                },
                else => |c| {
                    const color = if (std.ascii.isLower(c)) types.Color.black else types.Color.white;
                    const piece = std.ComptimeStringMap(types.PieceType, .{
                        .{ "p", .pawn },
                        .{ "r", .rook },
                        .{ "n", .knight },
                        .{ "b", .bishop },
                        .{ "q", .queen },
                        .{ "k", .king },
                    }).get(&.{std.ascii.toLower(c)}) orelse {
                        std.log.err("piece: {any}", .{c});
                        return FenError.InvalidPiecesPlacement;
                    };

                    switch (color) {
                        .black => {
                            std.debug.assert(!board.black_bitboard.state.isSet(bit_index));
                            board.black_bitboard.state.set(bit_index);
                        },
                        .white => {
                            std.debug.assert(!board.white_bitboard.state.isSet(bit_index));
                            board.white_bitboard.state.set(bit_index);
                        },
                    }

                    inline for (.{ .rook, .knight, .bishop, .pawn, .queen, .king }) |p| {
                        if (p == piece) {
                            std.debug.assert(!board.get_piece_board(p).state.isSet(bit_index));
                            board.get_piece_board(p).state.set(bit_index);
                        }
                    }

                    j += 1;
                },
            }
        }
    }

    if (i < 7) {
        std.log.err("pieces: {s}", .{part});
        return FenError.InvalidPiecesPlacement;
    }
}

/// Side to move is one lowercase letter for either White ('w') or Black ('b').
pub fn parse_side_to_move(board: *Board, part: []const u8) FenError!void {
    switch (part[0]) {
        'w' => {
            board.side_to_move = types.Color.white;
        },
        'b' => {
            board.side_to_move = types.Color.black;
        },
        else => {
            std.log.err("side_to_move: {s}", .{part});
            return FenError.InvalidSideToMove;
        },
    }
}

/// If neither side can castle, the symbol '-' is used, otherwise each of four individual castling rights
/// for king and queen castling for both sides are indicated by a sequence of one to four letters.
pub fn parse_castling_ability(board: *Board, part: []const u8) FenError!void {
    board.castling_ability = .{};

    if (part[0] != '-') {
        if (part.len > 4) {
            std.log.err("castling_ability: {s}", .{part});
            return FenError.InvalidCastlingAbility;
        }

        for (part) |seg| {
            switch (seg) {
                'K' => {
                    board.castling_ability.white_short = true;
                },
                'Q' => {
                    board.castling_ability.white_long = true;
                },
                'k' => {
                    board.castling_ability.black_short = true;
                },
                'q' => {
                    board.castling_ability.black_long = true;
                },
                else => {
                    std.log.err("castling_ability: {s}", .{part});
                    return FenError.InvalidCastlingAbility;
                },
            }
        }
    }
}

/// The en passant target square is specified after a double push of a pawn,
/// no matter whether an en passant capture is really possible or not.
/// Other moves than double pawn pushes imply the symbol '-' for this FEN field.
pub fn parse_en_passent_target_square(board: *Board, part: []const u8) FenError!void {
    switch (part.len) {
        1 => {
            if (part[0] != '-') {
                std.log.err("en_passent_target_square: {s}", .{part});
                return FenError.InvalidEnPassentSquare;
            }
            board.en_passent_target_square = null;
        },
        2 => {
            const file_letter = std.meta.stringToEnum(types.File, part[0..1]) orelse {
                std.log.err("en_passent_target_square: {s}", .{part});
                return FenError.InvalidEnPassentSquare;
            };
            const rank = std.meta.stringToEnum(types.Rank, part[1..2]) orelse {
                std.log.err("en_passent_target_square: {s}", .{part});
                return FenError.InvalidEnPassentSquare;
            };

            if (rank != .@"3" and rank != .@"6") {
                std.log.err("en_passent_target_square: {s}", .{part});
                return FenError.InvalidEnPassentSquare;
            }
            board.en_passent_target_square = .{ .rank = rank, .file = file_letter };
        },
        else => {
            std.log.err("en_passent_target_square: {s}", .{part});
            return FenError.InvalidEnPassentSquare;
        },
    }
}

/// The halfmove clock specifies a decimal number of half moves with respect to the 50 move draw rule.
/// It is reset to zero after a capture or a pawn move and incremented otherwise.
pub fn parse_halfmove_clock(board: *Board, part: []const u8) FenError!void {
    board.halfmove_clock = std.fmt.parseInt(types.HalfmoveClock, part, 10) catch {
        std.log.err("halfmove_clock: {s}", .{part});
        return FenError.InvalidHalfmoveClock;
    };
}

/// The number of the full moves in a game. It starts at 1, and is incremented after each Black's move.
pub fn parse_fullmove_counter(board: *Board, part: []const u8) FenError!void {
    board.fullmove_counter = std.fmt.parseInt(types.FullmoveCounter, part, 10) catch {
        std.log.err("fullmove_counter: {s}", .{part});
        return FenError.InvalidFullmoveCounter;
    };
}
