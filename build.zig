const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const definition_module = b.addModule("definitions", .{
        .root_source_file = b.path("src/cubedef/definitions.zig")
    });

    const utils_module = b.addModule("utils", .{
        .root_source_file = b.path("src/cubedef/utils.zig")
    });

    const cubie_module = b.addModule("cubie", .{
        .root_source_file = b.path("src/cubedef/cubiecube.zig"),
        .imports = &.{
            .{ .name = "definitions", .module=definition_module},
            .{ .name = "utils", .module=utils_module},
        }
    });

    const const_module = b.addModule("constants", .{
        .root_source_file = b.path("src/cubedef/constants.zig"),
        .imports = &.{
            .{ .name = "definitions", .module=definition_module},
            .{ .name = "cubie", .module=cubie_module}
        }
    });

    const facecube_module = b.addModule("facecube", .{
        .root_source_file = b.path("src/cubedef/facecube.zig"),
        .imports = &.{
            .{ .name = "definitions", .module=definition_module},
            .{ .name = "cubie", .module=cubie_module},
            .{ .name = "constants", .module=const_module}
        }
    });

    const pruning_module = b.addModule("prunning", .{
        .root_source_file = b.path("src/prunning/prunning.zig"),
        .imports = &.{
            .{ .name = "cubie", .module=cubie_module },
            .{ .name = "constants", .module=const_module },
        }
    });

    const pruning_generator = b.addExecutable(.{
        .name = "PruningGenerator",
        .root_source_file = b.path("src/prunning/prun_table_generator.zig"),
        .target = target,
        .optimize = optimize
    });
    pruning_generator.root_module.addImport("prunning", pruning_module);

    b.installArtifact(pruning_generator);
    const generator_ouput = b.addRunArtifact(pruning_generator);

    const corner_perm_file = generator_ouput.addOutputFileArg("corner_perm_move.zig");
    const corner_twist_file = generator_ouput.addOutputFileArg("corner_twist_move.zig");
    const corner_depth_file = generator_ouput.addOutputFileArg("corner_depth.zig");

    const table_module = b.addModule("prunning_table", .{
        .root_source_file = b.path("src/prunning/prun_tables.zig"),
        .imports = &.{
            .{.name = "corner_perm_prun_table", .module = b.createModule(.{ .root_source_file = corner_perm_file })},
            .{.name = "corner_twist_prun_table", .module = b.createModule(.{ .root_source_file = corner_twist_file })},
            .{.name = "depth_prun_table", .module = b.createModule(.{ .root_source_file = corner_depth_file })},
        }
    });

    const solver_module = b.addModule("solver", .{
        .root_source_file = b.path("src/solver/solver.zig"),
        .imports = &.{
            .{ .name = "definitions", .module=definition_module},
            .{ .name = "cubie", .module=cubie_module},
            .{ .name = "constants", .module=const_module},
            .{ .name = "facecube", .module=facecube_module},
            .{ .name = "prunning_tables", .module=table_module}
        },
    });

    const exe = b.addExecutable(.{
        .name = "Optimal2x2Solver",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);
    exe.root_module.addImport("constants", const_module);
    exe.root_module.addImport("definitions", definition_module);
    exe.root_module.addImport("cubie", cubie_module);
    exe.root_module.addImport("utils", utils_module);
    exe.root_module.addImport("facecube", facecube_module);
    exe.root_module.addImport("solver", solver_module);
    const clap = b.dependency("clap", .{});
    exe.root_module.addImport("clap", clap.module("clap"));
    exe.step.dependOn(&generator_ouput.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
