#include <iostream>
#include <vector>
#include <queue>
#include <algorithm>
#include <random>
#include <chrono>

using namespace std;

// Directions : droite, gauche, bas, haut
const int dx[] = { 0, 0, 1, -1 };
const int dy[] = { 1, -1, 0, 0 };

// Vérifier si une case est valide
bool isValid(int x, int y, int n, const vector<vector<int>>& P, const vector<vector<bool>>& visited) {
    return x >= 0 && x < n && y >= 0 && y < n && P[x][y] != -1 && !visited[x][y];
}

// Afficher la grille (carte des contours)
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
            if (P[i][j] == -1)
                cout << "██";
            else
                cout << " .";
        }
        cout << "\n";
    }
    cout << "\n";
}

// Afficher la grille avec les valeurs
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
            if (P[i][j] == -1)
                printf(" # ");
            else
                printf("%2d ", P[i][j]);
        }
        cout << "\n";
    }
    cout << "\n";
}

// BFS pour trouver le chemin
vector<pair<int, int>> findPath(int n, const vector<vector<int>>& P,
    int x1, int y1, int x2, int y2) {
    // Vérifier que les points sont valides
    if (x1 < 0 || x1 >= n || y1 < 0 || y1 >= n ||
        x2 < 0 || x2 >= n || y2 < 0 || y2 >= n) {
        cout << "Erreur: Coordonnees hors limites!\n";
        return {};
    }

    if (P[x1][y1] == -1 || P[x2][y2] == -1) {
        cout << "Erreur: Point de depart ou arrivee sur un contour (-1)!\n";
        return {};
    }

    vector<vector<bool>> visited(n, vector<bool>(n, false));
    vector<vector<pair<int, int>>> parent(n, vector<pair<int, int>>(n, { -1, -1 }));
    queue<pair<int, int>> q;

    visited[x1][y1] = true;
    q.push({ x1, y1 });

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
                parent[nx][ny] = { cx, cy };
                q.push({ nx, ny });
            }
        }
    }

    if (!found) {
        return {};
    }

    // Reconstruire le chemin
    vector<pair<int, int>> path;
    int cx = x2, cy = y2;
    while (cx != -1 && cy != -1) {
        path.push_back({ cx, cy });
        auto p = parent[cx][cy];
        cx = p.first;
        cy = p.second;
    }
    reverse(path.begin(), path.end());

    return path;
}

int main() {
    // Initialisation du générateur aléatoire
    auto seed = chrono::system_clock::now().time_since_epoch().count();
    mt19937 gen(seed);
    int n;
   ;
    cout << "VARIANTE 2.2 - RECHERCHE DE CHEMIN\n";
    cout << "Entrez la taille n de la grille (n x n) : ";
    cin >> n;

    uniform_int_distribution<> valDist(2, 9);
    vector<vector<int>> P(n, vector<int>(n));

    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            P[i][j] = valDist(gen);
        }
    }
    uniform_int_distribution<> contourDist(1, max(1, n / 5));  // M entre 1 et n/5
    int M = contourDist(gen);

    uniform_int_distribution<> centerDist(0, n - 1);
    uniform_int_distribution<> radiusDist(2, max(3, n / 8));

    cout << "Nombre de contours M = " << M << "\n";

    for (int c = 0; c < M; c++) {
        int cx = centerDist(gen);
        int cy = centerDist(gen);
        int r = radiusDist(gen);

        // Dessiner la bordure du carré (contour)
        for (int i = -r; i <= r; i++) {
            for (int j = -r; j <= r; j++) {
                if (abs(i) == r || abs(j) == r) {  // Seulement la bordure
                    int x = cx + i;
                    int y = cy + j;
                    if (x >= 0 && x < n && y >= 0 && y < n) {
                        P[x][y] = -1;  // Bordure du contour
                    }
                }
            }
        }
    }
    int x1, y1, x2, y2;

    cout << "Entrez P1 (x1 y1) [0.." << n - 1 << "] : ";
    cin >> x1 >> y1;
    cout << "Entrez P2 (x2 y2) [0.." << n - 1 << "] : ";
    cin >> x2 >> y2;

    printGrid(P);

    cout << "--- Grille complete avec valeurs ---\n";
    printGridDetailed(P);

    //  6. RECHERCHE DU CHEMIN 
    cout << "\n--- Recherche du chemin ---\n";
    cout << "P1 = (" << x1 << "," << y1 << ")\n";
    cout << "P2 = (" << x2 << "," << y2 << ")\n";

    vector<pair<int, int>> path = findPath(n, P, x1, y1, x2, y2);

    //  7. AFFICHAGE DU RESULTAT 
 
    cout << "RESULTAT\n";
  

    if (!path.empty()) {
        cout << "Trajectoire L trouvee !\n";
        cout << "Longueur : " << path.size() << " cellules\n";
        cout << "Chemin : ";
        for (size_t i = 0; i < path.size(); i++) {
            cout << "(" << path[i].first << "," << path[i].second << ")";
            if (i < path.size() - 1) cout << " -> ";
        }
        cout << "\n";
    }
    else {
        cout << "Aucune trajectoire L valide n'existe entre P1 et P2 !\n";
    }

    return 0;
}
