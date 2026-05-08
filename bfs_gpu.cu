#include "bfs_gpu.cuh"
#include <iostream>
#include <cuda_runtime.h>
#include <algorithm>

using namespace std;

#define CHECK_CUDA(call) { \
    cudaError_t err = call; \
    if (err != cudaSuccess) { \
        cerr << "Erreur CUDA: " << cudaGetErrorString(err) << " ligne " << __LINE__ << endl; \
        exit(1); \
    } \
}

// initialize the array
__global__ void initKernel(int* arr, int size, int value) {
    int idx = threadIdx.x + blockIdx.x * blockDim.x;
    if (idx < size) {
        arr[idx] = value;
    }
}

// mark the first visited point
__global__ void markStartKernel(bool* visited, int startIdx) {
    visited[startIdx] = true;
}

// Kernel d'exploration : Each thread explore one vertice of the border
__global__ void exploreKernel(
    int* grid,           // Grille (-1 = obstacle)
    bool* visited,       // Cases deja visitees
    int* frontier,       // Frontiere actuelle (indices)
    int* nextFrontier,   // Prochaine frontiere
    int* nextSize,       // Taille de la prochaine frontiere
    int* parent,         // Parent de chaque case
    int frontierSize,    // Taille de la frontiere actuelle
    int n,               // Taille de la grille
    int targetIdx,       // Indice de P2
    bool* found          // P2 trouve ?
) {
    int idx = threadIdx.x + blockIdx.x * blockDim.x;
    if (idx >= frontierSize) return;
    
    int current = frontier[idx];
    int cx = current / n;
    int cy = current % n;
    
    // Verifier les 4 voisins
    int neighbors[4][2] = {{cx-1, cy}, {cx+1, cy}, {cx, cy-1}, {cx, cy+1}};
    
    for (int i = 0; i < 4; i++) {
        int nx = neighbors[i][0];
        int ny = neighbors[i][1];
        
        if (nx >= 0 && nx < n && ny >= 0 && ny < n) {
            int nidx = nx * n + ny;
            
            // Si c'est la cible
            if (nidx == targetIdx) {
                parent[nidx] = current;
                *found = true;
                return;
            }
            
            // Si case libre et non visitee
            if (grid[nidx] != -1 && !visited[nidx]) {
                visited[nidx] = true;
                parent[nidx] = current;
                
                // Ajouter a la prochaine frontiere
                int pos = atomicAdd(nextSize, 1);
                nextFrontier[pos] = nidx;
            }
        }
    }
}

vector<pair<int,int>> bfsGPU(const vector<vector<int>>& P, int n, 
                              int x1, int y1, int x2, int y2) {
    
    cout << "\nBFS PARALLELE GPU \n";
    
    int size = n * n;
    int startIdx = x1 * n + y1;
    int targetIdx = x2 * n + y2;
    
    // 1. Convertir grille en tableau 1D
    int* h_grid = new int[size];
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            h_grid[i * n + j] = P[i][j];
        }
    }
    
    // 2. Allouer memoire GPU
    int *d_grid, *d_frontier, *d_nextFrontier, *d_parent;
    bool *d_visited, *d_found;
    int *d_frontierSize, *d_nextSize;
    
    CHECK_CUDA(cudaMalloc(&d_grid, size * sizeof(int)));
    CHECK_CUDA(cudaMalloc(&d_visited, size * sizeof(bool)));
    CHECK_CUDA(cudaMalloc(&d_parent, size * sizeof(int)));
    CHECK_CUDA(cudaMalloc(&d_frontier, size * sizeof(int)));
    CHECK_CUDA(cudaMalloc(&d_nextFrontier, size * sizeof(int)));
    CHECK_CUDA(cudaMalloc(&d_found, sizeof(bool)));
    CHECK_CUDA(cudaMalloc(&d_frontierSize, sizeof(int)));
    CHECK_CUDA(cudaMalloc(&d_nextSize, sizeof(int)));
    
    // 3. Copier donnees CPU > GPU
    CHECK_CUDA(cudaMemcpy(d_grid, h_grid, size * sizeof(int), cudaMemcpyHostToDevice));
    CHECK_CUDA(cudaMemset(d_visited, 0, size * sizeof(bool)));
    CHECK_CUDA(cudaMemset(d_parent, -1, size * sizeof(int)));
    
    // 4. Initialiser la frontiere avec P1
    int h_frontierSize = 1;
    int h_nextSize = 0;
    CHECK_CUDA(cudaMemcpy(d_frontier, &startIdx, sizeof(int), cudaMemcpyHostToDevice));
    CHECK_CUDA(cudaMemcpy(d_frontierSize, &h_frontierSize, sizeof(int), cudaMemcpyHostToDevice));
    CHECK_CUDA(cudaMemcpy(d_nextSize, &h_nextSize, sizeof(int), cudaMemcpyHostToDevice));
    
    bool h_found = false;
    CHECK_CUDA(cudaMemcpy(d_found, &h_found, sizeof(bool), cudaMemcpyHostToDevice));
    
    // 5. Marquer P1 comme visite
    CHECK_CUDA(cudaMemcpy(&d_visited[startIdx], &startIdx, sizeof(int), cudaMemcpyHostToDevice));
    
    // Configuration des threads
    int threadsPerBlock = 256;
    int blocksPerGrid = 256;
    
    cout << "Searching path..\n";
    
    // Boucle BFS
    int iterations = 0;
    while (h_frontierSize > 0 && !h_found) {
        // Reinitialiser nextSize
        h_nextSize = 0;
        CHECK_CUDA(cudaMemcpy(d_nextSize, &h_nextSize, sizeof(int), cudaMemcpyHostToDevice));
        
        // Lancer le kernel d'exploration
        exploreKernel<<<blocksPerGrid, threadsPerBlock>>>(
            d_grid, d_visited, d_frontier, d_nextFrontier, d_nextSize,
            d_parent, h_frontierSize, n, targetIdx, d_found
        );
        CHECK_CUDA(cudaDeviceSynchronize());
        
        // Recuperer nextSize et found
        CHECK_CUDA(cudaMemcpy(&h_nextSize, d_nextSize, sizeof(int), cudaMemcpyDeviceToHost));
        CHECK_CUDA(cudaMemcpy(&h_found, d_found, sizeof(bool), cudaMemcpyDeviceToHost));
        
        // Echanger frontiere et nextFrontier
        swap(d_frontier, d_nextFrontier);
        h_frontierSize = h_nextSize;
        
        iterations++;
        if (iterations % 10 == 0) {
            cout << "  Iteration " << iterations << ", frontier size: " << h_frontierSize << "\n";
        }
    }
    
    cout << "Research ended. Iterations: " << iterations << "\n";
    
    // 6. Reconstruire le chemin si trouve
    vector<pair<int,int>> path;
    
    if (h_found) {
        // Recuperer le tableau parent
        int* h_parent = new int[size];
        CHECK_CUDA(cudaMemcpy(h_parent, d_parent, size * sizeof(int), cudaMemcpyDeviceToHost));
        
        // Reconstruire le chemin
        int current = targetIdx;
        while (current != -1 && current != startIdx) {
            int x = current / n;
            int y = current % n;
            path.push_back({x, y});
            current = h_parent[current];
        }
        path.push_back({x1, y1});
        reverse(path.begin(), path.end());
        
        delete[] h_parent;
    }
    
    // 7. Nettoyage
    delete[] h_grid;
    cudaFree(d_grid);
    cudaFree(d_visited);
    cudaFree(d_parent);
    cudaFree(d_frontier);
    cudaFree(d_nextFrontier);
    cudaFree(d_found);
    cudaFree(d_frontierSize);
    cudaFree(d_nextSize);
    
    return path;
}