const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const definitions = @import("definitions");
const Move = definitions.Move;
const constants = @import("constants");
const CubieCube = @import("cubie").CubieCube;
const faceCube = @import("facecube");
const Solution = @import("solution.zig").Solution;
const depth_table = @import("prunning_tables").depth_prun_table;
const corner_perm_prun_table = @import("prunning_tables").corner_perm_prun_table;
const corner_twist_prun_table = @import("prunning_tables").corner_twist_prun_table;

pub const SolverError = Allocator.Error;
pub const SolveFromFaceCubeError = SolverError || faceCube.CubieCubeError;
pub const SolveFromStringError = SolveFromFaceCubeError || faceCube.CubeStringError;

const CubeStringPermIterator = struct {
    cube_string_perm: []const u8,
    p: []u8,
    i: u8 = 1,

    fn init(alloc: Allocator, cube_string: []const u8) Allocator.Error!CubeStringPermIterator {
        const pp = try alloc.alloc(u8, cube_string.len);
        for (0..cube_string.len) |i| {
            pp[i] = @intCast(i);
        }
        return CubeStringPermIterator{
            .cube_string_perm = try alloc.dupe(u8, cube_string),
            .p = pp,
        };
    }

    fn deinit(self: *CubeStringPermIterator, alloc: Allocator) void {
        alloc.free(self.cube_string_perm);
        alloc.free(self.p);
    }

    fn next(self: *CubeStringPermIterator) ?[]const u8 {
        while (self.i < self.cube_string_perm.len) {
            if (self.p[self.i] > 0) {
                self.p[self.i] -= 1;

                const j = if (self.i % 2 == 0) 0 else self.p[self.i];
                mem.swap(u8, @constCast(&self.cube_string_perm[j]), @constCast(&self.cube_string_perm[self.i]));

                self.i = 1;
                return self.cube_string_perm;
            } else {
                self.p[self.i] = @intCast(self.i);
                self.i += 1;
            }
        }
        return null;
    }
};

/// The struct that hodlds the methods to solve a cube
pub const Solver = struct {
    /// The maximum depth (number of moves) to search
    /// -1 for optimal
    /// defaults to -1
    /// note: if max_depth > -1 && max_depth <= optimal => crash
    max_depth: isize = -1,

    /// The maximum number of solutions to return
    /// -1 for no limit
    /// defaults to -1
    limit: isize = -1,

    /// Boolean flag that tells the solver to discard or not the redundant solutions
    /// true to keep all
    /// false to discart equivalent solutions
    all: bool = true,

    /// The allocator used by the solver
    allocator: Allocator,

    /// the list containing the solutions
    solutions: ArrayList(Solution),

    /// The init function
    pub fn init(allocator: Allocator, max_depth: ?isize, limit: ?isize, all: ?bool) SolverError!Solver {
        return Solver{
            .allocator = allocator,
            .max_depth = max_depth orelse -1,
            .limit = limit orelse -1,
            .all = all orelse false,
            .solutions = if (limit) |lim|
                if (lim >= 0) try ArrayList(Solution).initCapacity(allocator, @intCast(lim))
                else ArrayList(Solution).init(allocator)
            else ArrayList(Solution).init(allocator)
        };
    }

    /// deinit function, don't forget to call/defer when the program is terminating
    pub fn deinit(self: *Solver) void {
        for (self.solutions.items) |solution| {
            solution.deinit(self.allocator);
        }
        self.solutions.deinit();
    }

    /// The search method, it recursivly tries all the moves, cutting out branches when it detect they lead to nowhere
    fn search(self: *Solver, corner_perm: u16, corner_twist: u16, move_stack: *ArrayList(Move), depth: usize) !bool {
        if (depth == 0) {
            return self.add_solution(move_stack);
        } else {
            // try all the moves
            for (std.enums.values(Move), 0..) |move, idx| {
                // skip if move if it's the same two in a row
                if (move_stack.items.len > 0 and move.isSameLayer(move_stack.getLast())) {
                    continue;
                }

                // apply the move using the pre-computed tables instead of calculating it
                const new_corner_perm = corner_perm_prun_table[definitions.MoveCount * corner_perm + idx];
                const new_corner_twist = corner_twist_prun_table[definitions.MoveCount * corner_twist + idx];

                // skip the move if applying the it don't reduce the amount of moves towards the solved state
                if (depth_table[constants.N_TWIST * @as(usize, new_corner_perm) + @as(usize, new_corner_twist)] >= depth) {
                    continue;
                }

                // the move can lead to somewhere, we add it to the current solution and continue searching from here
                try move_stack.append(move);
                const limit_reached = try self.search(new_corner_perm, new_corner_twist, move_stack, depth - 1);

                // if the search has concluded in a solution been added to the list of solutions,
                // the solution limit might have been reached,
                // if it is, we recusivly break out of all loops, stopping the search entirely
                if (limit_reached) break;

                // else, the move has been searched for, so we discard it, creating a new branch in the search
                _ = move_stack.pop();
            }

            return false;
        }
    }

    fn add_solution(self: *Solver, move_stack: *ArrayList(Move)) SolverError!bool {
        const limit_reached = self.limit >= 0 and self.solutions.items.len >= self.limit;
        // don't add the solution if it's longer than the maximum depth or adding a solution would exceed the limit
        if ((self.max_depth < 0 or move_stack.items.len < self.max_depth) and !limit_reached) {
            const new_moves = try self.allocator.alloc(Move, move_stack.items.len);
            mem.copyForwards(Move, new_moves, move_stack.items);

            // we create a solution based on the current moves in the move_stack
            const new_solution = Solution.init(new_moves);

            // we mark the solution as existing or not if it is equivalent to a already existing solution
            // only if the 'all' flag is turned of, which it is by default
            // (see the definion of the equiv() function for the definition of "equivalent")
            var exists = false;
            if (!self.all) {
                for (self.solutions.items) |solution| {
                    if (new_solution.equiv(solution)) {
                        exists = true;
                        break;
                    }
                }
            }

            // we add the solution only if it doesn't exist already
            if (!exists) {
                try self.solutions.append(new_solution);
            } else {
                self.allocator.free(new_moves);
            }
        }

        // return if the limit has been reached or not
        return limit_reached;
    }

    /// the method that launches the search algorithm, it need a CubieCube as cube state
    pub fn solve_from_cubiecube(self: *Solver, cube: CubieCube) SolverError!usize {
        const perm = cube.get_cornerperm();
        const twist = cube.get_cornertwist();

        // the depth table gives use the minimum amount of moves requiered to solve the cube's state
        // based on it's permutation
        const optimal_depth = depth_table[constants.N_TWIST * @as(usize, perm) + @as(usize, twist)];

        // the actual depth to search is either provided by max_depth or the computed optimal depth
        const search_depth: usize = if (self.max_depth < 0) optimal_depth + 1 else @intCast(self.max_depth);

        // we initialize an empty move stack
        // // we initialize an empty move stack
        var move_stack = try ArrayList(Move).initCapacity(self.allocator, search_depth);
        defer move_stack.deinit();

        // since we loop on all depth from optimal to maxium, that means that all the solutions found
        // that have lenght that are in the range optimal_depth..search_depth will be returned (in the given limit)
        for (optimal_depth..search_depth) |depth| {
            _ = try self.search(perm, twist, &move_stack, depth);
        }

        // we return the number of solutions found
        return self.solutions.items.len;
    }

    /// wrapper around the main solve function that take a FaceCube and converts it to a CubieCube
    pub fn solve_from_facecube(self: *Solver, cube: faceCube.FaceCube) SolveFromFaceCubeError!usize {
        const cubiecube = try cube.to_cubie_cube();
        return try self.solve_from_cubiecube(cubiecube);
    }

    /// finds all the valid permutations of an incomplete cubstring
    /// it uses brut force by trying all the possibilities to filter the invalid ones
    /// there has to be a better way to do this but i'm too dumb for that
    fn find_permutations(self: *Solver, cube_string: []const u8) SolveFromStringError![][]const u8 {
        try faceCube.validate_cube_string(cube_string, true);

        // counts the occurences of each facelet, excluding the special empty facelet 'X'
        var counter = std.AutoHashMap(u8, u5).init(self.allocator);
        for (cube_string) |char| {
            if (char != 'X') {
                const entry = try counter.getOrPutValue(char, 0);
                try counter.put(char, entry.value_ptr.* + 1);
            }
        }

        // extract a list of possible values for the missing facelets
        var missings_facelets = try ArrayList(u8).initCapacity(self.allocator, 24);
        defer missings_facelets.deinit();

        var counter_iter = counter.iterator();
        while (counter_iter.next()) |entry| {
            missings_facelets.appendNTimesAssumeCapacity(entry.key_ptr.*, 4 - entry.value_ptr.*);
        }

        // create copy of the original cube string, for each replacing the special facelet 'X' with
        // a permuation of the missing facelets, ensuring all possible combinations are tried,
        // the result is put in a set to exclude duplicate cube strings
        var missing_perm_iter = try CubeStringPermIterator.init(self.allocator, try missings_facelets.toOwnedSlice());
        defer missing_perm_iter.deinit(self.allocator);

        var possible_cube_strings = StringHashMap(void).init(self.allocator);
        while (missing_perm_iter.next()) |perm| {
            var new_cube_string = try self.allocator.dupe(u8, cube_string);
            for (perm) |replacement| {
                new_cube_string[mem.indexOfScalar(u8, new_cube_string, 'X').?] = replacement;
            }
            try possible_cube_strings.put(new_cube_string, {});
        }

        // tries each newly formed cube string against the faceCube creation to see if it returns a valid FaceCube,
        // skipping the ones that throw errors
        var valid_cube_strings = try ArrayList([]const u8).initCapacity(self.allocator, possible_cube_strings.count());
        defer valid_cube_strings.deinit();

        var possible_cube_strings_iter = possible_cube_strings.keyIterator();
        while (possible_cube_strings_iter.next()) |possible_cube_string| {
            _ = faceCube.from_string(possible_cube_string.*) catch continue ;
            try valid_cube_strings.append(possible_cube_string.*);
        }

        return valid_cube_strings.toOwnedSlice();
    }

    /// wrapper around the solve_from_facecube function that take a string and converts it to a FaceCube
    pub fn solve_from_string(self: *Solver, cube_string: []const u8) SolveFromStringError!usize {
        // if it's an invariable cubstring
        if (mem.count(u8, cube_string, "X") == 0) {
            // convert to facecube and solve normaly
            const facecube = try faceCube.from_string(cube_string);
            return try self.solve_from_facecube(facecube);
        }

        // else find all possible permuations of the cubestring
        const permutations = try self.find_permutations(cube_string);

        // convert each permutation to facecube and find all solutions to all facecube, duplicate solutions are discarted
        for (permutations) |cube_string_perm| {
            const facecube = try faceCube.from_string(cube_string_perm);
            _ = try self.solve_from_facecube(facecube);
        }

        return self.solutions.items.len;
    }
};
