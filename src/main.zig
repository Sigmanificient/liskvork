const std = @import("std");
const builtin = @import("builtin");

const logz = @import("logz");
const zul = @import("zul");

const build_config = @import("build_config");

const config = @import("config.zig");
const server = @import("server.zig");
const utils = @import("utils.zig");

pub const PlayerOverrides = struct {
    game_player1: ?[]const u8,
    game_player2: ?[]const u8,
};

pub fn player_overrides(allocator: std.mem.Allocator) !PlayerOverrides {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var game_player1: ?[]const u8 = null;
    var game_player2: ?[]const u8 = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-p1")) {
            if (i + 1 >= args.len) return error.InvalidArguments;
            game_player1 = try allocator.dupe(u8, args[i + 1]);
            i += 1;
        } else if (std.mem.eql(u8, arg, "-p2")) {
            if (i + 1 >= args.len) return error.InvalidArguments;
            game_player2 = try allocator.dupe(u8, args[i + 1]);
            i += 1;
        }
    }

    return PlayerOverrides{
        .game_player1 = game_player1,
        .game_player2 = game_player2,
    };
}

pub fn main() !void {
    const start_time = std.time.milliTimestamp();

    defer {
        // Don't panic in release builds, that should only be needed in debug
        if (!build_config.use_system_allocator) {
            if (utils.gpa.deinit() != .ok and utils.is_debug_build)
                @panic("memory leaked");
        }
    }

    try logz.setup(utils.allocator, .{
        .level = .Warn,
        .output = .stdout,
        .encoding = .logfmt,
    });
    defer logz.deinit();

    var conf = try config.parse("config.ini");
    defer config.deinit_config(config.Config, &conf);

    const pl = try player_overrides(utils.allocator);
    if (pl.game_player1) |p1| conf.game_player1 = p1;
    if (pl.game_player2) |p2| conf.game_player2 = p2;

    try logz.setup(utils.allocator, .{
        .level = conf.log_level,
        .output = .stdout,
        .encoding = .logfmt,
    });

    logz.info().ctx("Launching liskvork").stringSafe("version", build_config.version).log();

    try server.launch_server(&conf);

    const close_time = std.time.milliTimestamp();
    const uptime = try zul.DateTime.fromUnix(close_time - start_time, .milliseconds);
    // TODO: Show days of uptime too (Not sure this is needed though)
    logz.info().ctx("Closing liskvork").fmt("uptime", "{}", .{uptime.time()}).log();
}

test {
    std.testing.refAllDecls(@This());
}
