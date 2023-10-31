/// https://www.chessprogramming.org/Zobrist_Hashing
const std = @import("std");
const types = @import("types.zig");

const zobrist_hashes = seedHashes();
pub const pieces_hash = zobrist_hashes[0];
pub const side_to_move_hash = zobrist_hashes[1];
pub const castling_rights_hash = zobrist_hashes[2];
pub const en_passent_file_hash = zobrist_hashes[3];

// TODO: pawns dont happen on the 1. and 8. rank
fn seedHashes() std.meta.Tuple(&.{
    [types.N_PIECES * 2][types.N_SQUARES]u64,
    u64,
    [4]u64,
    [8]u64,
}) {
    // Calculating random numbers behaves like a loop, so we increase the limit
    @setEvalBranchQuota(10000);

    var rnd = std.rand.DefaultPrng.init(4841709682173276450);

    var pieces: [types.N_PIECES * 2][types.N_SQUARES]u64 = std.mem.zeroes([types.N_PIECES * 2][types.N_SQUARES]u64);
    var side_to_move: u64 = 0;
    var castling_rights: [4]u64 = std.mem.zeroes([4]u64);
    var en_passent_file: [8]u64 = std.mem.zeroes([8]u64);

    for (0..pieces.len) |i| {
        for (0..types.N_SQUARES) |j| {
            pieces[i][j] = rnd.next();
        }
    }

    side_to_move = rnd.next();

    for (0..4) |i| {
        castling_rights[i] = rnd.next();
    }

    for (0..8) |i| {
        en_passent_file[i] = rnd.next();
    }

    return .{
        pieces,
        side_to_move,
        castling_rights,
        en_passent_file,
    };
}
