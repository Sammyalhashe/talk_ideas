const std = @import("std");
const log = std.log;
const Thread = std.Thread;
const Mutex = Thread.Mutex;
const Atomic = std.atomic.Atomic;


const NUM_RUNS = 1e8;
const NUM_THREADS = 16;

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

fn spawn(f: anytype, allocator: std.mem.Allocator) !void {
    const sc: Thread.SpawnConfig = .{.allocator = allocator};

    var threads: std.ArrayList(Thread) = std.ArrayList(Thread).init(allocator);

    for (0..NUM_THREADS) |_| {
        try threads.append(try Thread.spawn(sc, f, .{}));
    }

    for (threads.items) |t| {
        t.join();
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    try spawn(workOnAtomic, allocator);
}
