#ifndef BFS_GPU_CUH
#define BFS_GPU_CUH

#include <vector>
#include <utility>

// main fonction bfs on GPU
std::vector<std::pair<int,int>> bfsGPU(
    const std::vector<std::vector<int>>& P,
    int n, 
    int x1, int y1, 
    int x2, int y2
);

#endif