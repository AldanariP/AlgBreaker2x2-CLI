const std = @import("std");
const clap = @import("clap");
const SolverModule = @import("solver");
const Solver = SolverModule.Solver;
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

pub fn main() !void {
    var gpa = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help           Display this help
        \\-d, --depth <isize>  The maximum depth to search, -1 for optimal, default to optimal
        \\-l, --limit <isize>  The maximum number of solution to search for, -1 for no limit, defaults to no limit
        \\-a, --all            If true, all the solutions are returned, including duplicate solutions, defaults to false
        \\<str>
        \\
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = allocator
    }) catch |err| {
        diag.report(stderr, err) catch {};
        return err;
    };
    defer res.deinit();

    var solver = try Solver.init(
        allocator,
        res.args.depth,
        res.args.limit,
        res.args.all > 0
    );
    defer solver.deinit();

    const cube_string: []const u8 = res.positionals[0] orelse {
        try stderr.print("Missing positional argument: Cubestring\n", .{});
        return;
    };
    try stdout.print(
        "Solving cube: {s} (depth={d} limit={d} all={})\n",
        .{cube_string, solver.max_depth, solver.limit, solver.all}
    );

    const result = solver.solve_from_string(cube_string) catch |err| switch (err) {
        SolverModule.SolverError.OutOfMemory => {
            try stderr.print("Solver Error: {any}\n", .{err});
            return;
        },
        SolverModule.SolveFromStringError.InvalidCharacter => {
            try stderr.print(
                \\Invalid Cubstring: The given cubestring contains an invalid character
                \\The cubstring must contain only [U, R, F, D, L, B]
                \\
            , .{});
            return;
        },
        SolverModule.SolveFromStringError.InvalidLength => {
            try stderr.print(
                \\Invalid Cubstring: The given cubstring was of incorrect length
                \\The cubstring must be exaclty 24 characters long, was {d} characters long
                \\
            , .{cube_string.len});
            return;
        },
        SolverModule.SolveFromStringError.InvalidColorCount => {
            try stderr.print(
                \\Invalid Cubstring: The given invariable cubestring has an invalid color count
                \\In case of invariable custrings (no X character), all the colors must appear exactly 4 times
                \\
            , .{});
            return;
        },
        SolverModule.SolveFromStringError.InvalidCubeState  => {
            try stderr.print(
                \\Invalid CubeState: The given cubstring resulted in an impossible cube configuration
                \\
            , .{});
            return;
        },
        SolverModule.SolveFromFaceCubeError.InvalidFaceCube => {
            try stderr.print(
                \\Invalid CubeState: The given cubstring resulted in an impossible cube configuration
                \\
            , .{});
            return;
        }
    };

    try stdout.print("Found {d} solutions:\n", .{result});
    for (solver.solutions.items) |solution| {
        try stdout.print("{any}\n", .{solution});
    }
}

const ArgError = error {
    MissingCubeString
};