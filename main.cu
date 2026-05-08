#include <iostream>
#include <vector>
#include <queue>
#include <algorithm>
#include <random>
#include <chrono>

using namespace std;

// Inclure le header BFS GPU (on va le creer)
#include "bfs_gpu.cuh"

// ========== FONCTIONS CPU (ton code existant) ==========
const int dx[] = {0, 0, 1, -1};
const int dy[] = {1, -1, 0, 0};

bool isValid(int x, int y, int n, const vector<vector<int>>& P, const vector<vector<bool>>& visited) {
    return x >= 0 && x < n && y >= 0 && y < n && P[x][y] != -1 && !visited[x][y];
}

void printGrid(const vector<vector<int>>& P) {
    int n = P.size();
    cout << "\n   ";
    for (int j = 0; j < n; j++) printf("%2d", j);
    cout << "\n   ";
    for (int j = 0; j < n; j++) cout << "--";
    cout << "\n";
    for (int i = 0; i < n; i++) {
        printf("%2d|", i);
        for (int j = 0; j < n; j++) {
            if (P[i][j] == -1) cout << "--";
            else cout << " .";
        }
        cout << "\n";
    }
    cout << "\n";
}

void printGridDetailed(const vector<vector<int>>& P) {
    int n = P.size();
    cout << "\n   ";
    for (int j = 0; j < n; j++) printf("%3d", j);
    cout << "\n   ";
    for (int j = 0; j < n; j++) cout << "---";
    cout << "\n";
    for (int i = 0; i < n; i++) {
        printf("%2d|", i);
        for (int j = 0; j < n; j++) {
            if (P[i][j] == -1) printf(" # ");
            else printf("%2d ", P[i][j]);
        }
        cout << "\n";
    }
    cout << "\n";
}

// Version CPU du BFS (pour comparaison)
vector<pair<int, int>> findPathCPU(int n, const vector<vector<int>>& P,
    int x1, int y1, int x2, int y2) {
    
    if (P[x1][y1] == -1 || P[x2][y2] == -1) return {};
    
    vector<vector<bool>> visited(n, vector<bool>(n, false));
    vector<vector<pair<int, int>>> parent(n, vector<pair<int, int>>(n, {-1, -1}));
    queue<pair<int, int>> q;
    
    visited[x1][y1] = true;
    q.push({x1, y1});
    
    bool found = false;
    while (!q.empty()) {
        int cx = q.front().first;
        int cy = q.front().second;
        q.pop();
        
        if (cx == x2 && cy == y2) {
            found = true;
            break;
        }
        
        for (int i = 0; i < 4; i++) {
            int nx = cx + dx[i];
            int ny = cy + dy[i];
            if (isValid(nx, ny, n, P, visited)) {
                visited[nx][ny] = true;
                parent[nx][ny] = {cx, cy};
                q.push({nx, ny});
            }
        }
    }
    
    if (!found) return {};
    
    vector<pair<int, int>> path;
    int cx = x2, cy = y2;
    while (cx != -1 && cy != -1) {
        path.push_back({cx, cy});
        auto p = parent[cx][cy];
        cx = p.first;
        cy = p.second;
    }
    reverse(path.begin(), path.end());
    return path;
}

int main() {
    auto seed = chrono::system_clock::now().time_since_epoch().count();
    mt19937 gen(seed);
    int n = 5000;  // Taille fixe pour les tests (ou utilisez 32, 50, etc.)
    
    cout << "VARIANTE 2.2 - Find paths\n";
    cout << "Grid length : " << n << "x" << n << "\n";
    
    uniform_int_distribution<> valDist(2, 9);
    vector<vector<int>> P(n, vector<int>(n));
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            P[i][j] = valDist(gen);
        }
    }
    
    uniform_int_distribution<> contourDist(1, max(1, n / 5));
    int M = contourDist(gen);
    uniform_int_distribution<> centerDist(0, n - 1);
    uniform_int_distribution<> radiusDist(2, max(3, n / 8));
    
    cout << "Number of contours M = " << M << "\n";
    
    for (int c = 0; c < M; c++) {
        int cx = centerDist(gen);
        int cy = centerDist(gen);
        int r = radiusDist(gen);
        for (int i = -r; i <= r; i++) {
            for (int j = -r; j <= r; j++) {
                if (abs(i) == r || abs(j) == r) {
                    int x = cx + i;
                    int y = cy + j;
                    if (x >= 0 && x < n && y >= 0 && y < n) {
                        P[x][y] = -1;
                    }
                }
            }
        }
    }
    

    // Generer P1 et P2 aleatoirement sur des cases non bloquees
int x1, y1, x2, y2;

uniform_int_distribution<> posDist(0, n-1);

do {
    x1 = posDist(gen);
    y1 = posDist(gen);
} while (P[x1][y1] == -1);

do {
    x2 = posDist(gen);
    y2 = posDist(gen);
} while (P[x2][y2] == -1);

printf("P1 = (%d,%d) randomly generate\n", x1, y1);
printf("P2 = (%d,%d) randomly generate\n", x2, y2);
    
    
    // ========== VERSION CPU ==========
    cout << "\n--- Version CPU ---\n";
    auto startCPU = chrono::high_resolution_clock::now();
    vector<pair<int, int>> pathCPU = findPathCPU(n, P, x1, y1, x2, y2);
    auto endCPU = chrono::high_resolution_clock::now();
    auto timeCPU = chrono::duration_cast<chrono::microseconds>(endCPU - startCPU).count();
    
    if (!pathCPU.empty()) {
        cout << "Trajectory found (CPU) ! Length : " << pathCPU.size() << "\n";
        cout << "Time CPU : " << timeCPU << " microsecondes\n";
    } else {
        cout << "No path found (CPU)\n";
    }
    
   
    cout << "\n--- Version GPU ---\n";
    // TODO: Appeler bfsGPU()
    
    // ========== VERSION GPU ==========
    cout << "\n--- Version GPU (parallele) ---\n";
    auto startGPU = chrono::high_resolution_clock::now();
    vector<pair<int, int>> pathGPU = bfsGPU(P, n, x1, y1, x2, y2);
    auto endGPU = chrono::high_resolution_clock::now();
    auto timeGPU = chrono::duration_cast<chrono::microseconds>(endGPU - startGPU).count();
    
    if (!pathGPU.empty()) {
        cout << "Trajectory found (GPU) ! Length : " << pathGPU.size() << "\n";
        cout << "Time GPU : " << timeGPU << " microsecondes\n";
    } else {
        cout << "No path found (GPU)\n";
    }
    
    // Comparaison des temps
    cout << "\n=== COMPARISON ===\n";
    cout << "Time CPU: " << timeCPU << " ?s\n";
    cout << "Time GPU: " << timeGPU << " ?s\n";
    return 0;
}