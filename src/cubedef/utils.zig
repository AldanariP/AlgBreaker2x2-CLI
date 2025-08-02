fn getAbsLen(comptime from: anytype, comptime to: anytype) isize {
    return @abs(@as(isize, @intFromEnum(to)) - @intFromEnum(from));
}

pub fn enumRange(comptime from: anytype, comptime to: anytype) [getAbsLen(from, to)]usize {
    comptime {
        if (@TypeOf(from) != @TypeOf(to)) {
            @compileError("Both arguments must be of the same enum type");
        }
        if (!@typeInfo(@TypeOf(from)).@"enum".is_exhaustive) {
            @compileError("Enum type must be exhaustive");
        }
    }

    var array: [getAbsLen(from, to)]usize = undefined;
    const fromInt = @intFromEnum(from);
    const toInt = @intFromEnum(to);

    var item = @as(isize, fromInt);

    for (&array) |*i| {
        i.* = @as(usize, @intCast(item));
        item = if (fromInt < toInt) item + 1 else item - 1;
    }

    return array;
}