const CubieCube = @import("cubie").CubieCube;
const constants = @import("constants");
const N_CORNERS = constants.N_CORNERS;
const N_TWIST = constants.N_TWIST;
const N_MOVE = constants.N_MOVE;
const basicMoveCubes = constants.basicMoveCube;

pub fn create_corner_twist_prun_table() [N_TWIST * N_MOVE]u16 {
    var table = [_]u16{0} ** (N_TWIST * N_MOVE);
    var cube = CubieCube.default;

    for (0..N_TWIST) |i| {
        cube.set_cornertwist(@intCast(i));
        for (0..3) |j| { // three unique face U, R, F
            for (0..3) |k| { // three move for each face U, U2, U'
                cube.multiply(basicMoveCubes[j]);
                table[N_MOVE * i + 3 * j + k] = cube.get_cornertwist();
            }
            cube.multiply(basicMoveCubes[j]); // setup for next iteration
        }
    }

    return table;
}

pub fn create_corner_perm_prun_table() [N_CORNERS * N_MOVE]u16 {
    var table = [_]u16{0} ** (N_CORNERS * N_MOVE);
    var cube = CubieCube.default;

    for (0..N_CORNERS) |i| {
        cube.set_cornerperm(@intCast(i));
        for (0..3) |j| {
            for (0..3) |k| {
                cube.multiply(basicMoveCubes[j]);
                table[N_MOVE * i + 3 * j + k] = cube.get_cornerperm();
            }
            cube.multiply(basicMoveCubes[j]);
        }
    }

    return table;
}

pub fn create_depth_prun_table() [N_CORNERS * N_TWIST]u8 {
    var table = [_]u8{255} ** (N_CORNERS * N_TWIST);
    table[0] = 0;

    const corner_perm_prun_table = create_corner_perm_prun_table();
    const corner_twist_prun_table = create_corner_twist_prun_table();

    var done: u22 = 1;
    var depth: u8 = 0;

    while (done < N_CORNERS * N_TWIST) {
        for (0..N_CORNERS) |corner| {
            for (0..N_TWIST) |twist| {
                if (table[N_TWIST * corner + twist] == depth) {
                    for (0..N_MOVE) |move| {
                        const m_corners = @as(u32, corner_perm_prun_table[9 * corner + move]);
                        const m_twist = @as(u32, corner_twist_prun_table[9 * twist + move]);
                        const idx = N_TWIST * m_corners + m_twist;
                        if (table[idx] == 255) {
                            table[idx] = depth + 1;
                            done += 1;
                        }
                    }
                }
            }
        }
        depth += 1;
    }

    return table;
}