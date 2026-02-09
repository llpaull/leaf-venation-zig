const std = @import("std");
const raylib = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

const Vec2 = raylib.Vector2;

const screen_width = 800;
const screen_height = 600;

const SOURCES_PER_ITER = 10;
const MIN_DIST = 20;

const NODE_RADIUS = 5;
const SOURCE_RADIUS = NODE_RADIUS;
const NODE_COLOR = raylib.BLACK;
const SOURCE_COLOR = raylib.RED;

fn generateSources(allocator: std.mem.Allocator) ![]Vec2 {
    const newSources = try allocator.alloc(Vec2, SOURCES_PER_ITER);

    for (0..SOURCES_PER_ITER) |i| {
        newSources[i] = .{
            .x = @floatFromInt(raylib.GetRandomValue(0, screen_width)),
            .y = @floatFromInt(raylib.GetRandomValue(0, screen_height)),
        };
    }

    return newSources;
}

fn getClosestIndexes(sources: []const Vec2, nodes: []const Vec2, allocator: std.mem.Allocator) ![]usize {
    var indices = try allocator.alloc(usize, sources.len);
    for (0..sources.len) |i| {
        var min_dist = std.math.floatMax(f32);
        var min_idx: usize = 0;

        for (0..nodes.len) |j| {
            const dist = raylib.Vector2DistanceSqr(sources[i], nodes[j]);
            if (dist < min_dist) {
                min_dist = dist;
                min_idx = j;
            }
        }

        indices[i] = min_idx;
    }
    return indices;
}

fn GetDirections(sources: []const Vec2, nodes: []const Vec2, allocator: std.mem.Allocator) ![]Vec2 {
    const closest = try getClosestIndexes(sources, nodes, allocator);
    defer allocator.free(closest);

    var dirs = try allocator.alloc(Vec2, nodes.len);
    @memset(dirs, raylib.Vector2Zero());

    for (0..sources.len) |i| {
        const dir = raylib.Vector2Subtract(sources[i], nodes[closest[i]]);
        dirs[closest[i]] = raylib.Vector2Add(dirs[closest[i]], dir);
    }

    for (0..nodes.len) |i| {
        dirs[i] = raylib.Vector2Normalize(dirs[i]);
    }

    return dirs;
}

fn generateNodes(nodes: []const Vec2, dirs: []const Vec2, allocator: std.mem.Allocator) ![]Vec2 {
    var newNodes = std.ArrayList(Vec2).init(allocator);
    defer newNodes.deinit();

    for (0..nodes.len) |i| {
        if (raylib.Vector2LengthSqr(dirs[i]) > 0.001) {
            const newNode = raylib.Vector2Add(nodes[i], raylib.Vector2Scale(dirs[i], NODE_RADIUS * 2));
            try newNodes.append(newNode);
        }
    }

    const slice = try allocator.alloc(Vec2, newNodes.items.len);
    std.mem.copyForwards(Vec2, slice, newNodes.items);
    return slice;
}

fn getDeadSources(sources: []const Vec2, nodes: []const Vec2, allocator: std.mem.Allocator) ![]usize {
    var indices = std.ArrayList(usize).init(allocator);
    defer indices.deinit();

    const SqrMinDist = MIN_DIST * MIN_DIST;
    for (0..sources.len) |i| {
        for (nodes) |node| {
            if (raylib.Vector2DistanceSqr(node, sources[i]) < SqrMinDist) {
                try indices.append(i);
                break;
            }
        }
    }

    const slice = try allocator.alloc(usize, indices.items.len);
    std.mem.copyForwards(usize, slice, indices.items);
    return slice;
}

fn drawCircles(pos: []const Vec2, radius: f32, color: raylib.Color) void {
    for (pos) |p| {
        raylib.DrawCircle(@intFromFloat(p.x), @intFromFloat(p.y), radius, color);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var nodes = std.ArrayList(Vec2).init(allocator);
    defer nodes.deinit();

    // Initial node
    try nodes.append(.{
        .x = (screen_width / 2) - 5,
        .y = screen_height - (NODE_RADIUS * 2),
    });

    var sources = std.ArrayList(Vec2).init(allocator);
    defer sources.deinit();

    raylib.InitWindow(screen_width, screen_height, "Test");
    while (!raylib.WindowShouldClose()) {
        if (raylib.IsKeyPressed(raylib.KEY_SPACE)) {
            {
                // generate newSources
                const newSources = try generateSources(allocator);
                defer allocator.free(newSources);
                try sources.appendSlice(newSources);

                // kill sources too close
                const toKill = try getDeadSources(sources.items, nodes.items, allocator);
                defer allocator.free(toKill);

                std.mem.sort(usize, toKill, {}, std.sort.desc(usize));
                for (toKill) |idx| {
                    _ = sources.swapRemove(idx);
                }
            }

            {
                // create new nodes
                const directions = try GetDirections(sources.items, nodes.items, allocator);
                defer allocator.free(directions);

                const newNodes = try generateNodes(nodes.items, directions, allocator);
                defer allocator.free(newNodes);
                try nodes.appendSlice(newNodes);
            }

            {
                // kill sources too close
                const toKill = try getDeadSources(sources.items, nodes.items, allocator);
                defer allocator.free(toKill);

                std.mem.sort(usize, toKill, {}, std.sort.desc(usize));
                for (toKill) |idx| {
                    _ = sources.swapRemove(idx);
                }
            }
        }

        raylib.BeginDrawing();
        defer raylib.EndDrawing();

        raylib.ClearBackground(raylib.WHITE);
        drawCircles(nodes.items, NODE_RADIUS, NODE_COLOR);
        drawCircles(sources.items, SOURCE_RADIUS, SOURCE_COLOR);
    }
}
