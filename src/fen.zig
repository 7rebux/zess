/// https://www.chessprogramming.org/Forsyth-Edwards_Notation
/// <Piece Placement> <Side to move> <Castling ability> <En passsant target square> <Halfmove clock> <Fullmove counter>
const std = @import("std");
const types = @import("types.zig");
const zobrist = @import("zobrist.zig");
const Board = @import("board.zig").Board;

const FenError = error{
    TooManyParts,
    TooFewParts,
    TooManyRanks,
    TooFewRanks,
    InvalidPieceChar,
    InvalidPiecesPlacement,
    InvalidSideToMove,
    InvalidEnPassentTargetSquare,
    InvalidHalfmoveClock,
    InvalidFullmoveCounter,
    InvalidCastlingAbility,
};

pub fn parse(fen: []const u8) FenError!Board {
    var board: Board = undefined;
    var parts_it = std.mem.split(u8, fen, " ");
    var parts: [6][]const u8 = undefined;
    var i: u8 = 0;

    // make sure zobrist hashes are initialized
    std.debug.assert(zobrist.side_to_move_hash != 0);

    while (parts_it.next()) |part| : (i += 1) {
        if (i > 5) {
            std.log.warn("Too many FEN parts: {s}", .{fen});
            return FenError.TooManyParts;
        }

        parts[i] = part;
    }

    if (i < 5) {
        std.log.warn("Too few FEN parts: {s}", .{fen});
        return FenError.TooFewParts;
    }

    try parse_pieces(&board, parts[0]);
    try parse_side_to_move(&board, parts[1]);
    try parse_castling_ability(&board, parts[2]);
    try parse_en_passent_target_square(&board, parts[3]);
    try parse_halfmove_clock(&board, parts[4]);
    try parse_fullmove_counter(&board, parts[5]);

    return board;
}

test "parse start position" {
    var parsed_board = try parse("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");

    // TODO check bitboards or create mailbox and check that
    try std.testing.expectEqual(types.Color.white, parsed_board.side_to_move);
    try std.testing.expectEqual(types.Castling{ .black_short = true, .black_long = true, .white_short = true, .white_long = true }, parsed_board.castling_ability);
    try std.testing.expectEqual(@as(?types.File, null), parsed_board.en_passent_file);
    try std.testing.expectEqual(@as(types.HalfmoveClock, 0), parsed_board.halfmove_clock);
    try std.testing.expectEqual(@as(types.FullmoveCounter, 1), parsed_board.fullmove_counter);
}

fn parse_pieces(board: *Board, part: []const u8) FenError!void {
    var ranks_it = std.mem.split(u8, part, "/");
    var rank_index: u8 = 8;

    board.rook_bitboard = types.Bitboard.initEmpty();
    board.knight_bitboard = types.Bitboard.initEmpty();
    board.bishop_bitboard = types.Bitboard.initEmpty();
    board.queen_bitboard = types.Bitboard.initEmpty();
    board.king_bitboard = types.Bitboard.initEmpty();
    board.pawn_bitboard = types.Bitboard.initEmpty();
    board.white_bitboard = types.Bitboard.initEmpty();
    board.black_bitboard = types.Bitboard.initEmpty();

    while (rank_index > 0) {
        rank_index -= 1;

        const rank = ranks_it.next() orelse {
            std.log.warn("Not enough ranks: {s}", .{part});
            return FenError.TooFewRanks;
        };
        var file_index: u8 = 0;

        for (rank) |x| {
            var bit_index = ((file_index & 0b111) << 3) | (rank_index & 0b111);

            switch (x) {
                inline '1'...'8' => |inc| {
                    const val = comptime std.fmt.parseInt(u4, &.{inc}, 10) catch unreachable;
                    file_index += val;
                    if (file_index >= 8) break;
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
                        std.log.warn("Invalid piece char: {any}", .{c});
                        return FenError.InvalidPieceChar;
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

                    inline for (comptime std.enums.values(types.PieceType)) |p| {
                        if (p == piece) {
                            std.debug.assert(!board.get_piece_board(p).state.isSet(bit_index));
                            board.get_piece_board(p).state.set(bit_index);
                            const piece_index = (if (color == types.Color.white) @as(usize, 0) else @as(usize, 6)) + @intFromEnum(p);
                            board.zobrist_hash ^= zobrist.pieces_hash[piece_index][bit_index];
                        }
                    }

                    file_index += 1;
                },
            }
        }
    }

    if (ranks_it.next() != null) {
        std.log.warn("Too many ranks: {s}", .{part});
        return FenError.TooManyRanks;
    }
}

test "parse pieces with 1 rank" {
    var board: Board = undefined;
    try std.testing.expectError(
        error.TooFewRanks,
        parse_pieces(&board, "8"),
    );
}

test "parse pieces with 7 ranks" {
    var board: Board = undefined;
    try std.testing.expectError(
        error.TooFewRanks,
        parse_pieces(&board, "8/8/8/8/8/8/8"),
    );
}

test "parse pieces with 9 ranks" {
    var board: Board = undefined;
    try std.testing.expectError(
        error.TooManyRanks,
        parse_pieces(&board, "8/8/8/8/8/8/8/8/8"),
    );
}

fn parse_side_to_move(board: *Board, part: []const u8) FenError!void {
    if (part.len > 1) {
        std.log.warn("Invalid side to move: {s}", .{part});
        return FenError.InvalidSideToMove;
    }

    switch (part[0]) {
        'w' => {
            board.side_to_move = types.Color.white;
        },
        'b' => {
            board.side_to_move = types.Color.black;
            board.zobrist_hash ^= zobrist.side_to_move_hash;
        },
        else => {
            std.log.warn("Invalid side to move: {s}", .{part});
            return FenError.InvalidSideToMove;
        },
    }
}

test "parse side to move with w" {
    var board: Board = undefined;
    try parse_side_to_move(&board, "w");
    try std.testing.expectEqual(types.Color.white, board.side_to_move);
}

test "parse side to move with b" {
    var board: Board = undefined;
    try parse_side_to_move(&board, "b");
    try std.testing.expectEqual(types.Color.black, board.side_to_move);
}

test "parse side to move with x" {
    var board: Board = undefined;
    try std.testing.expectError(
        FenError.InvalidSideToMove,
        parse_side_to_move(&board, "x"),
    );
}

test "parse side to move with ww" {
    var board: Board = undefined;
    try std.testing.expectError(
        FenError.InvalidSideToMove,
        parse_side_to_move(&board, "ww"),
    );
}

fn parse_castling_ability(board: *Board, part: []const u8) FenError!void {
    board.castling_ability = .{};

    if (part[0] != '-') {
        if (part.len > 4) {
            std.log.warn("Invalid castling ability: {s}", .{part});
            return FenError.InvalidCastlingAbility;
        }

        for (part) |seg| {
            switch (seg) {
                'K' => {
                    board.castling_ability.white_short = true;
                    board.zobrist_hash ^= zobrist.castling_rights_hash[0];
                },
                'Q' => {
                    board.castling_ability.white_long = true;
                    board.zobrist_hash ^= zobrist.castling_rights_hash[1];
                },
                'k' => {
                    board.castling_ability.black_short = true;
                    board.zobrist_hash ^= zobrist.castling_rights_hash[2];
                },
                'q' => {
                    board.castling_ability.black_long = true;
                    board.zobrist_hash ^= zobrist.castling_rights_hash[3];
                },
                else => {
                    std.log.warn("Invalid castling ability: {s}", .{part});
                    return FenError.InvalidCastlingAbility;
                },
            }
        }
    }
}

test "parse castling ability with -" {
    var board: Board = undefined;
    try parse_castling_ability(&board, "-");
    try std.testing.expectEqual(
        types.Castling{
            .white_long = false,
            .white_short = false,
            .black_long = false,
            .black_short = false,
        },
        board.castling_ability,
    );
}

test "parse castling ability with KQkq" {
    var board: Board = undefined;
    try parse_castling_ability(&board, "KQkq");
    try std.testing.expectEqual(
        types.Castling{
            .white_long = true,
            .white_short = true,
            .black_long = true,
            .black_short = true,
        },
        board.castling_ability,
    );
}

test "parse castling ability with Kq" {
    var board: Board = undefined;
    try parse_castling_ability(&board, "Kq");
    try std.testing.expectEqual(
        types.Castling{
            .white_long = false,
            .white_short = true,
            .black_long = true,
            .black_short = false,
        },
        board.castling_ability,
    );
}

test "parse castling ability with x" {
    var board: Board = undefined;
    try std.testing.expectError(
        FenError.InvalidCastlingAbility,
        parse_castling_ability(&board, "x"),
    );
}

test "parse castling ability with KQkqK" {
    var board: Board = undefined;
    try std.testing.expectError(
        FenError.InvalidCastlingAbility,
        parse_castling_ability(&board, "KQkqK"),
    );
}

fn parse_en_passent_target_square(board: *Board, part: []const u8) FenError!void {
    switch (part.len) {
        1 => {
            if (part[0] != '-') {
                std.log.warn("Invalid en passent target square: {s}", .{part});
                return FenError.InvalidEnPassentTargetSquare;
            }
            board.en_passent_file = null;
        },
        2 => {
            const file_letter = std.meta.stringToEnum(types.File, part[0..1]) orelse {
                std.log.warn("Invalid en passent target square: {s}", .{part});
                return FenError.InvalidEnPassentTargetSquare;
            };

            // this is only used for fen validation purposes
            const rank = std.meta.stringToEnum(types.Rank, part[1..2]) orelse {
                std.log.warn("Invalid en passent target square: {s}", .{part});
                return FenError.InvalidEnPassentTargetSquare;
            };
            if (rank != .@"3" and rank != .@"6") {
                std.log.warn("Invalid en passent target square: {s}", .{part});
                return FenError.InvalidEnPassentTargetSquare;
            }

            board.en_passent_file = file_letter;
            board.zobrist_hash ^= zobrist.en_passent_file_hash[@intFromEnum(file_letter)];
        },
        else => {
            std.log.warn("Invalid en passent target square: {s}", .{part});
            return FenError.InvalidEnPassentTargetSquare;
        },
    }
}

test "parse en passent target square with -" {
    var board: Board = undefined;
    try parse_en_passent_target_square(&board, "-");
    try std.testing.expectEqual(
        @as(?types.File, null),
        board.en_passent_file,
    );
}

test "parse en passent target square with e3" {
    var board: Board = undefined;
    try parse_en_passent_target_square(&board, "e3");
    try std.testing.expectEqual(
        types.File.e,
        board.en_passent_file.?,
    );
}

test "parse en passent target square with d6" {
    var board: Board = undefined;
    try parse_en_passent_target_square(&board, "d6");
    try std.testing.expectEqual(
        types.File.d,
        board.en_passent_file.?,
    );
}

test "parse en passent target square with a1" {
    var board: Board = undefined;
    try std.testing.expectError(
        FenError.InvalidEnPassentTargetSquare,
        parse_en_passent_target_square(&board, "a1"),
    );
}

test "parse en passent target square with x3" {
    var board: Board = undefined;
    try std.testing.expectError(
        FenError.InvalidEnPassentTargetSquare,
        parse_en_passent_target_square(&board, "x3"),
    );
}

test "parse en passent target square with e3e3" {
    var board: Board = undefined;
    try std.testing.expectError(
        FenError.InvalidEnPassentTargetSquare,
        parse_en_passent_target_square(&board, "e3e3"),
    );
}

test "parse en passent target square with e" {
    var board: Board = undefined;
    try std.testing.expectError(
        FenError.InvalidEnPassentTargetSquare,
        parse_en_passent_target_square(&board, "e"),
    );
}

fn parse_halfmove_clock(board: *Board, part: []const u8) FenError!void {
    const halfmove_clock = std.fmt.parseInt(types.HalfmoveClock, part, 10) catch {
        std.log.warn("Invalid half move clock: {s}", .{part});
        return FenError.InvalidHalfmoveClock;
    };

    if (halfmove_clock > 50) {
        std.log.warn("Invalid half move clock: {s}", .{part});
        return FenError.InvalidHalfmoveClock;
    }
    board.halfmove_clock = halfmove_clock;
}

test "parse halfmove clock with 0" {
    var board: Board = undefined;
    try parse_halfmove_clock(&board, "0");
    try std.testing.expectEqual(@as(types.HalfmoveClock, 0), board.halfmove_clock);
}

test "parse halfmove clock with 25" {
    var board: Board = undefined;
    try parse_halfmove_clock(&board, "25");
    try std.testing.expectEqual(@as(types.HalfmoveClock, 25), board.halfmove_clock);
}

test "parse halfmove clock with x" {
    var board: Board = undefined;
    try std.testing.expectError(
        FenError.InvalidHalfmoveClock,
        parse_halfmove_clock(&board, "x"),
    );
}

test "parse halfmove clock with 51" {
    var board: Board = undefined;
    try std.testing.expectError(
        FenError.InvalidHalfmoveClock,
        parse_halfmove_clock(&board, "51"),
    );
}

test "parse halfmove clock with -1" {
    var board: Board = undefined;
    try std.testing.expectError(
        FenError.InvalidHalfmoveClock,
        parse_halfmove_clock(&board, "-1"),
    );
}

fn parse_fullmove_counter(board: *Board, part: []const u8) FenError!void {
    const fullmove_counter = std.fmt.parseInt(types.FullmoveCounter, part, 10) catch {
        std.log.warn("Invalid full move counter: {s}", .{part});
        return FenError.InvalidFullmoveCounter;
    };

    if (fullmove_counter > 99) {
        std.log.warn("Invalid full move counter: {s}", .{part});
        return FenError.InvalidFullmoveCounter;
    }
    board.fullmove_counter = fullmove_counter;
}

test "parse fullmove counter with 0" {
    var board: Board = undefined;
    try parse_fullmove_counter(&board, "0");
    try std.testing.expectEqual(@as(types.FullmoveCounter, 0), board.fullmove_counter);
}

test "parse fullmove counter with 50" {
    var board: Board = undefined;
    try parse_fullmove_counter(&board, "50");
    try std.testing.expectEqual(@as(types.FullmoveCounter, 50), board.fullmove_counter);
}

test "parse fullmove counter with x" {
    var board: Board = undefined;
    try std.testing.expectError(
        FenError.InvalidFullmoveCounter,
        parse_fullmove_counter(&board, "x"),
    );
}

test "parse fullmove counter with 100" {
    var board: Board = undefined;
    try std.testing.expectError(
        FenError.InvalidFullmoveCounter,
        parse_fullmove_counter(&board, "100"),
    );
}

test "parse fullmove counter with -1" {
    var board: Board = undefined;
    try std.testing.expectError(
        FenError.InvalidFullmoveCounter,
        parse_fullmove_counter(&board, "-1"),
    );
}

pub fn write(board: *const Board, writer: anytype) !void {
    try write_pieces(board, writer);
    try writer.writeAll(" ");
    try write_side_to_move(board, writer);
    try writer.writeAll(" ");
    try write_castling_ability(board, writer);
    try writer.writeAll(" ");
    try write_en_passent_target_square(board, writer);
    try writer.writeAll(" ");
    try write_halfmove_clock(board, writer);
    try writer.writeAll(" ");
    try write_fullmove_counter(board, writer);
}

fn write_pieces(board: *const Board, writer: anytype) !void {
    var rank_index: u8 = 8;

    while (rank_index > 0) {
        rank_index -= 1;

        var empty: u8 = 0;

        for (0..8) |file_index| {
            const bit_index = ((file_index & 0b111) << 3) | (rank_index & 0b111);
            var piece_char: u8 = ' ';

            inline for (.{
                board.rook_bitboard,
                board.pawn_bitboard,
                board.king_bitboard,
                board.knight_bitboard,
                board.bishop_bitboard,
                board.queen_bitboard,
            }, .{ 'r', 'p', 'k', 'n', 'b', 'q' }) |piece_board, char| {
                if (piece_board.state.isSet(bit_index)) {
                    piece_char = if (board.white_bitboard.state.isSet(bit_index)) std.ascii.toUpper(char) else char;
                    break;
                }
            }

            if (piece_char == ' ') {
                empty += 1;
            } else {
                if (empty != 0) {
                    try writer.print("{}", .{empty});
                    empty = 0;
                }

                try writer.print("{c}", .{piece_char});
            }

            if (empty != 0 and file_index == 7) {
                try writer.print("{}", .{empty});
            }
        }

        if (rank_index > 0) {
            try writer.writeAll("/");
        }
    }
}

// TODO: implement
test "write pieces" {
    return error.SkipZigTest;
}

fn write_side_to_move(board: *const Board, writer: anytype) !void {
    const color: u8 = if (board.side_to_move == types.Color.black) 'b' else 'w';
    try writer.print("{c}", .{color});
}

test "write side to move with white" {
    var board: Board = undefined;
    var buffer: [1]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    board.side_to_move = types.Color.white;
    try write_side_to_move(&board, stream.writer());

    try std.testing.expectEqual(@as(usize, 1), stream.pos);
    try std.testing.expectEqual(@as(u8, 'w'), buffer[0]);
}

test "write side to move with black" {
    var board: Board = undefined;
    var buffer: [1]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    board.side_to_move = types.Color.black;
    try write_side_to_move(&board, stream.writer());

    try std.testing.expectEqual(@as(usize, 1), stream.pos);
    try std.testing.expectEqual(@as(u8, 'b'), buffer[0]);
}

fn write_castling_ability(board: *const Board, writer: anytype) !void {
    if (@as(u4, @bitCast(board.castling_ability)) == 0) {
        try writer.writeAll("-");
    } else {
        inline for (.{
            board.castling_ability.white_short,
            board.castling_ability.white_long,
            board.castling_ability.black_short,
            board.castling_ability.black_long,
        }, .{ 'K', 'Q', 'k', 'q' }) |flag, char| {
            if (flag) {
                try writer.print("{c}", .{char});
            }
        }
    }
}

test "write castling ability with -" {
    var board: Board = undefined;
    var buffer: [1]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    board.castling_ability = types.Castling{
        .white_long = false,
        .white_short = false,
        .black_long = false,
        .black_short = false,
    };
    try write_castling_ability(&board, stream.writer());

    try std.testing.expectEqual(@as(usize, 1), stream.pos);
    try std.testing.expectEqual(@as(u8, '-'), buffer[0]);
}

test "write castling ability with KQkq" {
    var board: Board = undefined;
    var buffer: [4]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    board.castling_ability = types.Castling{
        .white_long = true,
        .white_short = true,
        .black_long = true,
        .black_short = true,
    };
    try write_castling_ability(&board, stream.writer());

    try std.testing.expectEqual(@as(usize, 4), stream.pos);
    try std.testing.expectEqualStrings("KQkq", &buffer);
}

test "write castling ability with Kq" {
    var board: Board = undefined;
    var buffer: [2]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    board.castling_ability = types.Castling{
        .white_long = false,
        .white_short = true,
        .black_long = true,
        .black_short = false,
    };
    try write_castling_ability(&board, stream.writer());

    try std.testing.expectEqual(@as(usize, 2), stream.pos);
    try std.testing.expectEqualStrings("Kq", &buffer);
}

fn write_en_passent_target_square(board: *const Board, writer: anytype) !void {
    const rank = if (board.side_to_move == types.Color.black) types.Rank.@"3" else types.Rank.@"6";

    if (board.en_passent_file) |file| {
        try writer.print("{s}{s}", .{ @tagName(file), @tagName(rank) });
    } else {
        try writer.writeAll("-");
    }
}

test "write en passent target square with null" {
    var board: Board = undefined;
    var buffer: [1]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    board.en_passent_file = null;
    try write_en_passent_target_square(&board, stream.writer());

    try std.testing.expectEqual(@as(usize, 1), stream.pos);
    try std.testing.expectEqualStrings("-", &buffer);
}

test "write en passent target square with e and black to move" {
    var board: Board = undefined;
    var buffer: [2]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    board.en_passent_file = types.File.e;
    board.side_to_move = types.Color.black;
    try write_en_passent_target_square(&board, stream.writer());

    try std.testing.expectEqual(@as(usize, 2), stream.pos);
    try std.testing.expectEqualStrings("e3", &buffer);
}

fn write_halfmove_clock(board: *const Board, writer: anytype) !void {
    try writer.print("{}", .{board.halfmove_clock});
}

test "write halfmove clock with 25" {
    var board: Board = undefined;
    var buffer: [2]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    board.halfmove_clock = 25;
    try write_halfmove_clock(&board, stream.writer());

    try std.testing.expectEqual(@as(usize, 2), stream.pos);
    try std.testing.expectEqualStrings("25", &buffer);
}

fn write_fullmove_counter(board: *const Board, writer: anytype) !void {
    try writer.print("{}", .{board.fullmove_counter});
}

test "write fullmove counter with 50" {
    var board: Board = undefined;
    var buffer: [2]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    board.fullmove_counter = 50;
    try write_fullmove_counter(&board, stream.writer());

    try std.testing.expectEqual(@as(usize, 2), stream.pos);
    try std.testing.expectEqualStrings("50", &buffer);
}
