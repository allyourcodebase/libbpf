const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("libbpf-upstream", .{});
    const libelf_dep = b.dependency("libelf", .{
        .target = target,
        .optimize = optimize,
    });
    const zlib_dep = b.dependency("zlib", .{
        .target = target,
        .optimize = optimize,
    });

    const lib = portableStaticLibrary(b, "bpf", target, optimize);
    portableLinkLibC(lib);

    portableLinkLibrary(lib, libelf_dep.artifact("elf"));
    portableLinkLibrary(lib, zlib_dep.artifact("z"));

    const sources = [_][]const u8{
        "bpf.c",
        "btf.c",
        "libbpf.c",
        "libbpf_utils.c",
        "netlink.c",
        "nlattr.c",
        "bpf_prog_linfo.c",
        "libbpf_probes.c",
        "btf_dump.c",
        "btf_iter.c",
        "btf_relocate.c",
        "hashmap.c",
        "strset.c",
        "ringbuf.c",
        "linker.c",
        "gen_loader.c",
        "relo_core.c",
        "usdt.c",
        "zip.c",
        "elf.c",
        "features.c",
    };

    const cflags = [_][]const u8{
        "-D_LARGEFILE64_SOURCE",
        "-D_FILE_OFFSET_BITS=64",
        "-std=gnu89",
    };

    portableAddCSourceFiles(lib, .{
        .root = upstream.path("src"),
        .files = &sources,
        .flags = &cflags,
    });

    // libbpf internal includes
    portableAddIncludePath(lib, upstream.path("src"));
    portableAddIncludePath(lib, upstream.path("include"));
    portableAddIncludePath(lib, upstream.path("include/uapi"));

    // Install public BPF headers (for BPF program compilation and userspace API)
    const public_headers = [_][]const u8{
        "bpf.h",
        "libbpf.h",
        "btf.h",
        "libbpf_common.h",
        "libbpf_legacy.h",
        "bpf_helpers.h",
        "bpf_helper_defs.h",
        "bpf_tracing.h",
        "bpf_endian.h",
        "bpf_core_read.h",
        "skel_internal.h",
        "libbpf_version.h",
        "usdt.bpf.h",
    };

    for (public_headers) |header| {
        lib.installHeader(upstream.path(b.fmt("src/{s}", .{header})), b.fmt("bpf/{s}", .{header}));
    }

    // Install all include/ subdirectories for BPF program compilation
    lib.installHeadersDirectory(upstream.path("include/uapi/linux"), "linux", .{});
    lib.installHeadersDirectory(upstream.path("include/linux"), "linux", .{});
    lib.installHeadersDirectory(upstream.path("include/asm"), "asm", .{});

    b.installArtifact(lib);
}

// Portable helpers for Zig 0.14/0.15+ compatibility

const PortableAddCSourceFilesOptions = if (@hasDecl(std.Build.Module, "AddCSourceFilesOptions"))
    std.Build.Module.AddCSourceFilesOptions
else
    std.Build.Step.Compile.AddCSourceFilesOptions;

fn portableAddCSourceFiles(c: *std.Build.Step.Compile, options: PortableAddCSourceFilesOptions) void {
    if (@hasDecl(std.Build.Step.Compile, "addCSourceFiles")) {
        c.addCSourceFiles(options);
    } else {
        c.root_module.addCSourceFiles(options);
    }
}

fn portableLinkLibC(c: *std.Build.Step.Compile) void {
    if (@hasDecl(std.Build.Step.Compile, "linkLibC")) {
        c.linkLibC();
    } else {
        c.root_module.link_libc = true;
    }
}

fn portableLinkLibrary(c: *std.Build.Step.Compile, library: *std.Build.Step.Compile) void {
    if (@hasDecl(std.Build.Step.Compile, "linkLibrary")) {
        c.linkLibrary(library);
    } else {
        c.root_module.linkLibrary(library);
    }
}

fn portableAddIncludePath(c: *std.Build.Step.Compile, path: std.Build.LazyPath) void {
    if (@hasDecl(std.Build.Step.Compile, "addIncludePath")) {
        c.addIncludePath(path);
    } else {
        c.root_module.addIncludePath(path);
    }
}

fn portableStaticLibrary(b: *std.Build, name: []const u8, target: anytype, optimize: anytype) *std.Build.Step.Compile {
    if (@hasDecl(std.Build, "addStaticLibrary")) {
        return b.addStaticLibrary(.{
          .name = name,
          .target = target,
          .optimize = optimize,
        });
    } else {
        return b.addLibrary(.{
          .name = name,
          .linkage = .static,
          .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
          }),
        });
    }
}
