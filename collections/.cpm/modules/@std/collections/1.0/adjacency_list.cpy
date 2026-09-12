import stdlib

# AdjacencyList: graph representation using adjacency lists for efficient
# neighbor iteration. Cache-friendly flat pools: edge data stored densely.

struct AdjacencyList:
    size_t* edge_to
    void** edge_weight
    size_t* edge_start
    size_t* degree
    size_t capacity
    size_t size
    size_t num_vertices
    int directed

public def create_adjacency_list(num_vertices size_t, directed int) -> AdjacencyList:
    AdjacencyList al
    al.num_vertices = num_vertices
    al.capacity = num_vertices * (size_t)4
    al.size = (size_t)0
    al.directed = directed
    al.edge_to = (size_t*)malloc(al.capacity * (size_t)sizeof(size_t))
    al.edge_weight = (void**)malloc(al.capacity * (size_t)sizeof(void*))
    al.edge_start = (size_t*)malloc((num_vertices + (size_t)1) * (size_t)sizeof(size_t))
    al.degree = (size_t*)malloc(num_vertices * (size_t)sizeof(size_t))
    size_t i = (size_t)0
    for i in range((int)al.capacity):
        al.edge_to[i] = (size_t)0x7FFFFFFF
        al.edge_weight[i] = 0
    for i in range((int)(num_vertices + (size_t)1)):
        al.edge_start[i] = (size_t)0
    for i in range((int)num_vertices):
        al.degree[i] = (size_t)0
    return al

public def _al_grow(al AdjacencyList) -> AdjacencyList:
    size_t new_cap = al.capacity * (size_t)2
    size_t* new_edge_to = (size_t*)malloc(new_cap * (size_t)sizeof(size_t))
    void** new_edge_weight = (void**)malloc(new_cap * (size_t)sizeof(void*))
    size_t i = (size_t)0
    for i in range((int)al.capacity):
        new_edge_to[i] = al.edge_to[i]
        new_edge_weight[i] = al.edge_weight[i]
    for i in range((int)al.capacity, (int)new_cap):
        new_edge_to[i] = (size_t)0x7FFFFFFF
        new_edge_weight[i] = 0
    free(al.edge_to)
    free(al.edge_weight)
    al.edge_to = new_edge_to
    al.edge_weight = new_edge_weight
    al.capacity = new_cap
    return al

public def adjacency_list_add_edge(al AdjacencyList, from size_t, to size_t, weight void*) -> AdjacencyList:
    if from >= al.num_vertices or to >= al.num_vertices:
        return al
    if al.size >= al.capacity:
        al = _al_grow(al)
    size_t pos = al.edge_start[from] + al.degree[from]
    if pos >= al.capacity:
        al = _al_grow(al)
        pos = al.edge_start[from] + al.degree[from]
    al.edge_to[pos] = to
    al.edge_weight[pos] = weight
    al.degree[from] += (size_t)1
    al.size += (size_t)1
    size_t i = from + (size_t)1
    while i <= al.num_vertices:
        al.edge_start[i] += (size_t)1
        i += (size_t)1
    if al.directed == 0:
        if al.size >= al.capacity:
            al = _al_grow(al)
        pos = al.edge_start[to] + al.degree[to]
        if pos >= al.capacity:
            al = _al_grow(al)
            pos = al.edge_start[to] + al.degree[to]
        al.edge_to[pos] = from
        al.edge_weight[pos] = weight
        al.degree[to] += (size_t)1
        al.size += (size_t)1
        i = to + (size_t)1
        while i <= al.num_vertices:
            al.edge_start[i] += (size_t)1
            i += (size_t)1
    return al

public def adjacency_list_remove_edge(al AdjacencyList, from size_t, to size_t) -> AdjacencyList:
    if from >= al.num_vertices or to >= al.num_vertices:
        return al
    size_t start = al.edge_start[from]
    size_t end = start + al.degree[from]
    size_t k = start
    size_t found = (size_t)0x7FFFFFFF
    for k in range((int)start, (int)end):
        if al.edge_to[k] == to:
            found = k
            break
    if found == (size_t)0x7FFFFFFF:
        return al
    size_t j = found
    for j in range((int)found, (int)end - (int)1):
        al.edge_to[j] = al.edge_to[j + (size_t)1]
        al.edge_weight[j] = al.edge_weight[j + (size_t)1]
    al.edge_to[end - (size_t)1] = (size_t)0x7FFFFFFF
    al.edge_weight[end - (size_t)1] = 0
    al.degree[from] -= (size_t)1
    al.size -= (size_t)1
    size_t i = from + (size_t)1
    while i <= al.num_vertices:
        al.edge_start[i] -= (size_t)1
        i += (size_t)1
    if al.directed == 0:
        start = al.edge_start[to]
        end = start + al.degree[to]
        k = start
        found = (size_t)0x7FFFFFFF
        for k in range((int)start, (int)end):
            if al.edge_to[k] == from:
                found = k
                break
        if found != (size_t)0x7FFFFFFF:
            j = found
            for j in range((int)found, (int)end - (int)1):
                al.edge_to[j] = al.edge_to[j + (size_t)1]
                al.edge_weight[j] = al.edge_weight[j + (size_t)1]
            al.edge_to[end - (size_t)1] = (size_t)0x7FFFFFFF
            al.edge_weight[end - (size_t)1] = 0
            al.degree[to] -= (size_t)1
            al.size -= (size_t)1
            i = to + (size_t)1
            while i <= al.num_vertices:
                al.edge_start[i] -= (size_t)1
                i += (size_t)1
    return al

public def adjacency_list_has_edge(al AdjacencyList, from size_t, to size_t) -> int:
    if from >= al.num_vertices or to >= al.num_vertices:
        return 0
    size_t start = al.edge_start[from]
    size_t end = start + al.degree[from]
    size_t k = start
    for k in range((int)start, (int)end):
        if al.edge_to[k] == to:
            return 1
    return 0

public def adjacency_list_get_weight(al AdjacencyList, from size_t, to size_t) -> void*:
    if from >= al.num_vertices or to >= al.num_vertices:
        return 0
    size_t start = al.edge_start[from]
    size_t end = start + al.degree[from]
    size_t k = start
    for k in range((int)start, (int)end):
        if al.edge_to[k] == to:
            return al.edge_weight[k]
    return 0

public def adjacency_list_degree(al AdjacencyList, vertex size_t) -> size_t:
    if vertex >= al.num_vertices:
        return (size_t)0
    return al.degree[vertex]

public def adjacency_list_vertices(al AdjacencyList) -> size_t:
    return al.num_vertices

public def adjacency_list_edges(al AdjacencyList) -> size_t:
    return al.size

public def adjacency_list_is_directed(al AdjacencyList) -> int:
    return al.directed

public def adjacency_list_clear(al AdjacencyList) -> AdjacencyList:
    al.size = (size_t)0
    size_t i = (size_t)0
    for i in range((int)al.capacity):
        al.edge_to[i] = (size_t)0x7FFFFFFF
        al.edge_weight[i] = 0
    for i in range((int)(al.num_vertices + (size_t)1)):
        al.edge_start[i] = (size_t)0
    for i in range((int)al.num_vertices):
        al.degree[i] = (size_t)0
    return al
