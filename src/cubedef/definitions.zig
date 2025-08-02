const FormatOptions = @import("std").fmt.FormatOptions;

pub const ColorCount = @typeInfo(Color).@"enum".fields.len;
pub const CornerCount = @typeInfo(Corner).@"enum".fields.len;
pub const MoveCount = @typeInfo(Move).@"enum".fields.len;
pub const FaceletCount = @typeInfo(Facelet).@"enum".fields.len;

pub const Color = enum {
    U, R, F, D, L, B,

    pub fn format(color: Color, comptime _: []const u8, _: FormatOptions, writer: anytype) !void {
        const ansi_code= switch (color) {
            Color.U => "97",  // white
            Color.R => "91",  // red
            Color.F => "92",  // green
            Color.D => "93",  // yellow
            Color.L => "95",  // purple because there is no orange
            Color.B => "94",  // blue
        };

        _ = try writer.print("\x1b[0;{s}mColor.{s}\x1b[0m", .{ansi_code, @tagName(color)});
    }
};

pub const Corner = enum {
    URF, UFL, ULB, UBR,
    DRB, DFR, DLF, DBL
};

pub const Move = enum {
    U1, U2, U3,
    R1, R2, R3,
    F1, F2, F3,

    pub fn format(move: Move, comptime _: []const u8, _: FormatOptions, writer: anytype) !void {
        const name = @tagName(move);
        const value = switch (name[1]) {
            '1' => name[0..1],
            '2' => name[0..2],
            '3' => switch (name[0]) {
                'U' => "U'",
                'R' => "R'",
                'F' => "F'",
                else => unreachable,
            },
            else => unreachable
        };
        _ = try writer.print("{s}", .{value});
    }

    pub fn isU(self: Move) bool {
        return @intFromEnum(self) < 3;
    }

    pub fn isSameLayer(self: Move, other: Move) bool {
        // (U1, U2, U3) / 3 => 0
        // (R1, R2, R3) / 3 => 1
        // (F1, F2, F3) / 3 => 2
        return @intFromEnum(self) / 3 == @intFromEnum(other) / 3;
    }
};

pub const Facelet = enum {
    ///          |********|
    ///          |*U1**U2*|
    ///          |********|
    ///          |*U3**U4*|
    ///          |********|
    /// |********|********|********|********|
    /// |*L1**L2*|*F1**F2*|*R1**R2*|*B1**B2*|
    /// |********|********|********|********|
    /// |*L3**L4*|*F3**F4*|*R3**R4*|*B3**B4*|
    /// |********|********|********|********|
    ///          |********|
    ///          |*D1**D2*|
    ///          |********|
    ///          |*D3**D4*|
    ///          |********|

    U1, U2, U3, U4,
    R1, R2, R3, R4,
    F1, F2, F3, F4,
    D1, D2, D3, D4,
    L1, L2, L3, L4,
    B1, B2, B3, B4
};
