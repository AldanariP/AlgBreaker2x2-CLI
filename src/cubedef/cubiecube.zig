const std = @import("std");
const indexOfScalar = std.mem.indexOfScalar;
const definitions = @import("definitions");
const Corner = definitions.Corner;
const Color = definitions.Color;
const enumRange = @import("utils").enumRange;

pub const CubieCube = struct {
    cp: [8]Corner,
    co: [8]u3,

    pub const default: CubieCube = .{
        .cp = .{Corner.URF, Corner.UFL, Corner.ULB, Corner.UBR, Corner.DRB, Corner.DFR, Corner.DLF, Corner.DBL},
        .co = [_]u3{0} ** 8,
    };

    pub fn multiply(self: *CubieCube, other: CubieCube) void {
        const old_cp = self.cp;
        const old_co = self.co;

        for (0..definitions.CornerCount) |c| {
            const c_index = @intFromEnum(other.cp[c]);
            const ori_a = old_co[c_index];
            const ori_b = other.co[c];
            var ori: i8 = 0;
            if (ori_a < 3) {
                ori = ori_a + ori_b;
                if (ori_b < 3 and 3 <= ori or ori >= 6) {
                    ori -= 3;
                }
            } else {
                ori = ori_a - ori_b;
                if (ori_b < 3 and ori < 3 or ori < 0) {
                    ori += 3;
                }
            }

            self.cp[c] = old_cp[c_index];
            self.co[c] = @intCast(ori); //if (ori_a < 3) @mod(ori_a + ori_b, 3) else @mod(ori_a - ori_b, 3);
        }
    }

    pub fn get_cornertwist(self: CubieCube) u16 {
        var res: u16 = 0;
        for (enumRange(Corner.URF, Corner.DLF)) |i| {
            res = 3 * res + @as(u16, self.co[i]);
        }
        return res;
    }

    pub fn set_cornertwist(self: *CubieCube, twist: u16) void {
        var twistParity: u8 = 0;
        var remainingTwist = twist;
        var i: u8 = @intFromEnum(Corner.DLF);

        while (i > @intFromEnum(Corner.URF)) : (i -= 1) {
            self.co[i - 1] = @intCast(@mod(remainingTwist, 3));
            twistParity += self.co[i - 1];
            remainingTwist /= 3;
        }

        self.co[@intFromEnum(Corner.DLF)] = @intCast((3 - twistParity % 3) % 3);
    }

    pub fn get_cornerperm(self: CubieCube) u16 {
        var perm = self.cp;
        var res: u16 = 0;

        for (enumRange(Corner.DBL, Corner.URF)) |i| {
            var k: u16 = 0;
            // TODO further optimize once it's working
            // if (@intFromEnum(perm[i]) != i) {
            //     const idx = indexOfScalar(Corner, &perm, @enumFromInt(i)).?;
            //     k = idx + 1;
            //     const temp = perm;
            //     for (0..i) |j| {
            //         perm[@mod((@as(isize, j) - k), i)] = temp[j];
            //     }
            // }
            while (@intFromEnum(perm[i]) != i) {
                const temp = perm[0];
                for (0..i) |j| {
                    perm[j] = perm[j + 1];
                }
                perm[i] = temp;
                k += 1;
            }
            res = @as(u16, @intCast(i + 1)) * res + k;
        }
        return res;
    }

    pub fn set_cornerperm(self: *CubieCube, idx: u16) void {
        self.cp = .{Corner.URF, Corner.UFL, Corner.ULB, Corner.UBR, Corner.DRB, Corner.DFR, Corner.DLF, Corner.DBL};
        var index = @as(usize, idx);
        for (0..definitions.CornerCount) |i| {
            var k = @mod(index, i + 1);
            index /= i + 1;
            while (k > 0) {
                const temp = self.cp[i];
                for (0..i) |j| {
                    self.cp[i - j] = self.cp[i - (j + 1)];
                }
                self.cp[0] = temp;
                k -= 1;
            }
        }
    }

    pub fn verify(self: CubieCube) bool {
        // each corner must be present exactly once
        var occurences = [_]usize{0} ** 8;
        for (0..definitions.CornerCount) |i| {
            const idx = @intFromEnum(self.cp[i]);
            occurences[idx] += 1;
            if (occurences[idx] != 1) return false;
        }

        // The sum of the orientation must be a multiple of 3
        var sum: u8 = 0;
        for (self.co) |ori| {
            sum += ori;
        }
        return @mod(sum, 3) == 0;
    }
};
