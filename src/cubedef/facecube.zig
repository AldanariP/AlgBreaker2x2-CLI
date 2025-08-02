const std = @import("std");
const ascii = std.ascii;
const mem = std.mem;
const parseInt = std.fmt.parseInt;

const CubieCube = @import("cubie").CubieCube;
const constants = @import("constants");
const definitions = @import("definitions");
const Corner = definitions.Corner;
const Color = definitions.Color;
const Facelet = definitions.Facelet;

pub const FaceCube = struct {
    facelets: [24]Color,

    pub const default: FaceCube = .{ .facelets = .{
        Color.U, Color.U, Color.U, Color.U,
        Color.R, Color.R, Color.R, Color.R,
        Color.F, Color.F, Color.F, Color.F,
        Color.D, Color.D, Color.D, Color.D,
        Color.B, Color.B, Color.B, Color.B,
        Color.L, Color.L, Color.L, Color.L,
    }};

    pub fn to_cubie_cube(self: FaceCube) CubieCubeError!CubieCube {
        var cube = CubieCube {.cp = .{undefined} ** 8, .co = [_]u3{0} ** 8};

        for (0..definitions.CornerCount) |i| {
            const fac = constants.cornerFacelet[i];

            var ori: u3 = 0;
            var color = self.facelets[@intFromEnum(fac[ori])];
            while (color != Color.U and color != Color.D) {
                ori += 1;
                if (ori >= fac.len) {
                    return CubieCubeError.InvalidFaceCube;
                }
                color = self.facelets[@intFromEnum(fac[ori])];
            }

            const col0 = color;
            const col1 = self.facelets[@intFromEnum(fac[@mod(ori + 1, 3)])];
            const col2 = self.facelets[@intFromEnum(fac[@mod(ori + 2, 3)])];

            var perm: u4 = 0;
            var cornerColor = constants.cornerColors[perm];
            while (col0 != cornerColor[0] or col1 != cornerColor[1] or col2 != cornerColor[2]) : (perm += 1) {
                if (perm >= constants.cornerColors.len) break;
                cornerColor = constants.cornerColors[perm];
            } else {
                cube.cp[i] = @enumFromInt(perm -| 1);
                cube.co[i] = ori;
            }
        }

        return cube;
    }
};

pub const CubeStringError = error{
    InvalidLength,
    InvalidCharacter,
    InvalidColorCount,
    InvalidCubeState
};

pub const CubieCubeError = error {
    InvalidFaceCube
};

pub fn from_string(string: []const u8) CubeStringError!FaceCube {
    try validate_cube_string(string, false);

    var facelets: [24]Color = undefined;
    for (string, 0..) |char, i| {
        const upper_char = ascii.toUpper(char);
        facelets[i] = switch (upper_char) {
            'U' => Color.U,
            'R' => Color.R,
            'F' => Color.F,
            'L' => Color.L,
            'D' => Color.D,
            'B' => Color.B,
            else => unreachable
        };
    }

    const dbl_facelets = constants.cornerFacelet[@intFromEnum(Corner.DBL)];
    const dbl_colors = constants.cornerColors[@intFromEnum(Corner.DBL)];

    var map_col: [6]?Color = .{null} ** 6;  // stores the color of the dbl corner in the current facelets
    for (0..3) |i| {
        map_col[@intFromEnum(facelets[@intFromEnum(dbl_facelets[i])])] = dbl_colors[i];
    }

    var empty: [3]usize = undefined;  // store the indexes where map_col is null
    var index: u3 = 0;
    for (map_col, 0..) |color, i| {
        if (color) |_| {
            continue;
        } else {
            empty[index] = i;
            index += 1;
        }
    }

    const permutations = [6][3]Color {
        [_]Color {Color.U, Color.R, Color.F},
        [_]Color {Color.U, Color.F, Color.R},
        [_]Color {Color.R, Color.U, Color.F},
        [_]Color {Color.R, Color.F, Color.U},
        [_]Color {Color.F, Color.U, Color.R},
        [_]Color {Color.F, Color.R, Color.U},
    };

    const temp_faclets = facelets;
    for (permutations) |permutation| {
        for (empty, 0..) |idx, i| {
            map_col[idx] = permutation[i];
        }

        for (0..definitions.FaceletCount) |i| {
            facelets[i] = map_col[@intFromEnum(facelets[i])].?;
        }

        const facecube = FaceCube{.facelets = facelets};
        const cubiecube = facecube.to_cubie_cube() catch continue;
        if (cubiecube.verify()) {
            return facecube;
        }

        facelets = temp_faclets;
    }

    return CubeStringError.InvalidCubeState;
}

pub fn validate_cube_string(string: []const u8, accept_empty: bool) CubeStringError!void {
    if (string.len != 24) {
        return CubeStringError.InvalidLength;
    }

    var u: u8 = 0;
    var r: u8 = 0;
    var f: u8 = 0;
    var l: u8 = 0;
    var d: u8 = 0;
    var b: u8 = 0;
    var x: u8 = 0;

    for (string) |char| {
        const upper_char = ascii.toUpper(char);
        switch (upper_char) {
            'U' => u += 1,
            'R' => r += 1,
            'F' => f += 1,
            'L' => l += 1,
            'D' => d += 1,
            'B' => b += 1,
            'X' => x += 1,
            else => return CubeStringError.InvalidCharacter,
        }
    }

    if (!accept_empty and x > 0) {
        return CubeStringError.InvalidCharacter;
    }

    if (!accept_empty and (u != 4 or r != 4 or f != 4 or l != 4 or d != 4 or b != 4)) {
        return CubeStringError.InvalidColorCount;
    }

    return;
}
