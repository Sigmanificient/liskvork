const std = @import("std");

const targets = [_]std.Target.Query{
    .{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
    },
    .{
        .cpu_arch = .aarch64,
        .os_tag = .linux,
    },
    .{
        .cpu_arch = .x86_64,
        .os_tag = .macos,
    },
    .{
        .cpu_arch = .aarch64,
        .os_tag = .macos,
    },
    .{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
    },
    .{
        .cpu_arch = .aarch64,
        .os_tag = .windows,
    },
};

pub fn build(b: *std.Build) !void {
    const std_target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const version = b.option([]const u8, "version", "application version string") orelse "0.0.0-dev";

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const build_all = b.option(
        bool,
        "build_all",
        "Whether to build all platforms possible",
    ) orelse false;

    if (build_all) {
        for (targets) |target| {
            const exe_name = try std.fmt.allocPrint(
                allocator,
                "{s}-{s}-{s}",
                .{
                    "liskvork",
                    version,
                    try b.resolveTargetQuery(target).result.linuxTriple(allocator),
                },
            );
            const liskvork = b.addExecutable(.{
                .name = exe_name,
                .target = b.resolveTargetQuery(target),
                .optimize = optimize,
                .root_source_file = b.path("src/main.zig"),
            });
            const pkg = b.dependency("ini", .{ .target = target, .optimize = optimize });
            liskvork.root_module.addImport("ini", pkg.module("ini"));
            const options = b.addOptions();
            options.addOption([]const u8, "version", version);
            liskvork.root_module.addOptions("build_config", options);
            b.installArtifact(liskvork);
        }
    }

    const liskvork = b.addExecutable(.{
        .name = "liskvork",
        .target = std_target,
        .optimize = optimize,
        .root_source_file = b.path("src/main.zig"),
    });

    const pkg = b.dependency("ini", .{ .target = std_target, .optimize = optimize });
    liskvork.root_module.addImport("ini", pkg.module("ini"));

    const options = b.addOptions();
    options.addOption([]const u8, "version", version);
    liskvork.root_module.addOptions("build_config", options);

    b.installArtifact(liskvork);

    const run_liskvork = b.addRunArtifact(liskvork);

    const run_step = b.step("run", "Run liskvork");
    run_step.dependOn(&run_liskvork.step);

    const test_step = b.step("test", "Run unit tests");

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = std_target,
        .optimize = optimize,
    });
    unit_tests.root_module.addOptions("build_config", options);
    unit_tests.root_module.addImport("ini", pkg.module("ini"));

    const run_unit_tests = b.addRunArtifact(unit_tests);
    test_step.dependOn(&run_unit_tests.step);
}
