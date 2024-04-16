const std = @import("std");
const log = std.log;
const Thread = std.Thread;
const Mutex = Thread.Mutex;
const Atomic = std.atomic.Atomic;
const Time = std.time;

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("plot.h");
});

const NUM_RUNS = 1e8;

var g_count: usize = 0;
var g_atomicCount: Atomic(usize) = Atomic(usize).init(0);
var g_mutex: Mutex = Mutex{};

fn workUnprotected() void {
    for (0..NUM_RUNS) |_| {
        g_count += 1;
    }
}

fn workMutexProtected() void {
    for (0..NUM_RUNS) |_| {
        g_mutex.lock();
        defer g_mutex.unlock();
        g_count += 1;
    }
}

fn workOnAtomic() void {
    for (0..NUM_RUNS) |_| {
        // returns the previous value
        _ = g_atomicCount.fetchAdd(1, .SeqCst);
    }
}

fn spawn(f: anytype, num_threads: u8, allocator: std.mem.Allocator) !void {
    const sc: Thread.SpawnConfig = .{ .allocator = allocator };

    var threads: std.ArrayList(Thread) = std.ArrayList(Thread).init(allocator);

    for (0..num_threads) |_| {
        try threads.append(try Thread.spawn(sc, f, .{}));
    }

    for (threads.items) |t| {
        t.join();
    }
}

fn plotData(outfileName: []const u8, xs: []const f64, ys: []const f64) void {
    var outfile: ?*c.FILE = c.fopen(@ptrCast(outfileName), "w+");

    if (outfile == null) {
        return;
    }

    var p_params: ?*c.plPlotterParams = c.pl_newplparams();
    const PAGESIZE = "letter";
    _ = c.pl_setplparam(p_params, "PAGESIZE", @ptrCast(@constCast(PAGESIZE)));

    // create plot
    const plot = c.pl_newpl_r("png", null, outfile, null, p_params);

    if (plot == null) {
        return;
    }

    if (0 > c.pl_openpl_r(plot)) {
        return;
    }

    // set coordinate system
    _ = c.pl_fspace_r(plot, 0, 0, 100, 100);

    // set line thickness
    _ = c.pl_flinewidth_r(plot, 0.25);

    // set line colour
    _ = c.pl_pencolorname_r(plot, "red");

    // erase graphics display
    _ = c.pl_erase_r(plot);

    // position the graphics cursor
    _ = c.pl_fmove_r(plot, 0, 0);

    for (0..xs.len) |idx| {
        _ = c.pl_fcontrel_r(plot, xs[idx], ys[idx]);
    }

    // delete plot
    _ = c.pl_deletepl_r(plot);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const num_threads = [_]f64{ 4, 8, 16, 32, 64 };

    var times: [num_threads.len]f64 = [_]f64{0.0} ** num_threads.len;

    // const workerType = *const fn () void;
    // inline for ([_]workerType{workOnAtomic}) |f| {
    inline for (0.., num_threads) |idx, t| {
        const begin = Time.timestamp();
        try spawn(workUnprotected, t, allocator);
        const end = Time.timestamp();

        times[idx] = @floatFromInt(end - begin);
    }

    plotData("time.png", &num_threads, &times);
    // }
}
