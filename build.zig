const std = @import("std");

pub fn build(b: *std.Build) !void {
    const lib = b.addExecutable(.{
        .name = "cart",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
        .optimize = std.builtin.OptimizeMode.ReleaseSmall,
    });

    lib.entry = .disabled;
    lib.import_memory = true;
    lib.initial_memory = 65536;
    lib.max_memory = 65536;
    lib.stack_size = 14752;

    // Export WASM-4 symbols
    lib.export_symbol_names = &[_][]const u8{ "start", "update" };

    b.installArtifact(lib);

    const run_cmd = b.addSystemCommand(
        &.{
            "w4",
            "run-native",
            "zig-out/bin/cart.wasm",
        },
    );
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "run the cart");
    run_step.dependOn(&run_cmd.step);
}
