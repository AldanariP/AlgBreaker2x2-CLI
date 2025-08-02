const Move = @import("definitions").Move;
const Allocator = @import("std").mem.Allocator;
const FormatOptions = @import("std").fmt.FormatOptions;

pub const Solution = struct {
    __moves: []const Move,
    moves: []const Move,
    pre_AUF: ?Move,
    post_AUF: ?Move,

    pub fn init(moves: []const Move) Solution {
        const start: u1 = if (moves.len > 0 and moves[0].isU()) 1 else 0;
        const end: usize = if (moves.len > 1 and moves[moves.len - 1].isU()) moves.len - 1 else moves.len;
        return Solution {
            .__moves = moves,
            .moves = moves[start..end],
            .pre_AUF = if (start == 1) moves[0] else null,
            .post_AUF = if (end == moves.len - 1) moves[moves.len - 1] else null,
        };
    }

    pub fn deinit(self: Solution, allocator: Allocator) void {
        allocator.free(self.__moves);
    }

    pub fn equiv(self: Solution, other: Solution) bool {
        if (self.moves.len != other.moves.len) {
            return false;
        }

        for (self.moves, other.moves) |s_move, o_move| {
            if (s_move != o_move) {
                return false;
            }
        }

        return true;
    }

    pub fn format(solution: Solution, comptime _: []const u8, _: FormatOptions, writer: anytype) !void {
        _ = if (solution.pre_AUF != null) try writer.print("({s}) ", .{solution.pre_AUF.?});
        for (solution.moves) |move| _ = try writer.print("{} ", .{move});
        _ = if (solution.post_AUF != null) try writer.print("({s}) ", .{solution.post_AUF.?});
        _ = try writer.print("({d}f) ({d}f*)", .{solution.__moves.len, solution.moves.len});
    }
};
