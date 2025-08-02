const definitions = @import("definitions");
const Facelet = definitions.Facelet;
const Color = definitions.Color;
const Corner = definitions.Corner;
const CubieCube = @import("cubie").CubieCube;

// see the definition of the Move enum
pub const N_MOVE = 9;
// 3^6 possible orientation
pub const N_TWIST = 729;
// 7! possible permitation
pub const N_CORNERS = 5040;

// definition of the facelet of a each corner of a cube
pub const cornerFacelet = [8][3]Facelet {
    [_]Facelet{Facelet.U4, Facelet.R1, Facelet.F2},
    [_]Facelet{Facelet.U3, Facelet.F1, Facelet.L2},
    [_]Facelet{Facelet.U1, Facelet.L1, Facelet.B2},
    [_]Facelet{Facelet.U2, Facelet.B1, Facelet.R2},
    [_]Facelet{Facelet.D4, Facelet.R4, Facelet.B3},
    [_]Facelet{Facelet.D2, Facelet.F4, Facelet.R3},
    [_]Facelet{Facelet.D1, Facelet.L4, Facelet.F3},
    [_]Facelet{Facelet.D3, Facelet.B4, Facelet.L3}
};

// definition of the color of each corner
pub const cornerColors = [8][3]Color {
    [_]Color{Color.U, Color.R, Color.F},
    [_]Color{Color.U, Color.F, Color.L},
    [_]Color{Color.U, Color.L, Color.B},
    [_]Color{Color.U, Color.B, Color.R},
    [_]Color{Color.D, Color.R, Color.B},
    [_]Color{Color.D, Color.F, Color.R},
    [_]Color{Color.D, Color.L, Color.F},
    [_]Color{Color.D, Color.B, Color.L}
};

// A move is represented by a cube wich the move has been applied to it
// to apply a move to a cube, we only need to multiply its permutation and orientation
// by the permutation and orientation of the move cube
// we only neeed to define the 3 basic move since they are only used to create the prun tables
// and the algorithm only need to iterate through them one
pub const basicMoveCube = [3]CubieCube {
    CubieCube{  // U
        .cp = .{Corner.UBR, Corner.URF, Corner.UFL, Corner.ULB, Corner.DRB, Corner.DFR, Corner.DLF, Corner.DBL},
        .co = .{0, 0, 0, 0, 0, 0, 0, 0}
    },
    CubieCube{  // R
        .cp = .{Corner.DFR, Corner.UFL, Corner.ULB, Corner.URF, Corner.UBR, Corner.DRB, Corner.DLF, Corner.DBL},
        .co = .{2, 0, 0, 1, 2, 1, 0, 0}
    },
    CubieCube{  // F
        .cp = .{Corner.UFL, Corner.DLF, Corner.ULB, Corner.UBR, Corner.DRB, Corner.URF, Corner.DFR, Corner.DBL},
        .co = .{1, 2, 0, 0, 0, 2, 1, 0}
    }
};
