/// https://www.chessprogramming.org/Zobrist_Hashing
const std = @import("std");
const types = @import("types.zig");

// TODO: pawns dont happen on the 1. and 8. rank
pub var pieces_hash: [types.N_PIECES * 2][types.N_SQUARES]u64 = std.mem.zeroes([types.N_PIECES * 2][types.N_SQUARES]u64);
pub var side_to_move_hash: u64 = 0;
pub var castling_rights_hash: [4]u64 = std.mem.zeroes([4]u64);
pub var en_passent_file_hash: [8]u64 = std.mem.zeroes([8]u64);

pub fn init() void {
    var rnd = std.rand.DefaultPrng.init(4841709682173276450);
    var i: u8 = 0;

    while (i < pieces_hash.len) : (i += 1) {
        var j: u8 = 0;
        while (j < types.N_SQUARES) : (j += 1) {
            pieces_hash[i][j] = rnd.next();
        }
    }

    side_to_move_hash = rnd.next();

    i = 0;
    while (i < 4) : (i += 1) {
        castling_rights_hash[i] = rnd.next();
    }

    i = 0;
    while (i < 8) : (i += 1) {
        en_passent_file_hash[i] = rnd.next();
    }
}
