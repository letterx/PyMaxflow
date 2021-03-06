
# distutils: language = c++
# cython: embedsignature = True

import numpy as np

# Define PY_ARRAY_UNIQUE_SYMBOL
cdef extern from "pyarray_symbol.h":
    pass

cimport numpy as np

np.import_array()

cdef extern from "fastmin.h":
    cdef object c_aexpansion "aexpansion"(int, np.ndarray, np.ndarray, np.ndarray) except +
    cdef object c_abswap "abswap"(int, int, np.ndarray, np.ndarray, np.ndarray) except +

def aexpansion_grid_step(int alpha, np.ndarray D, np.ndarray V, np.ndarray labels):
    """
    .. note:: Unless you really need to, you should not call this function.
    
    Perform an iteration of the alpha-expansion algorithm.
    ``labels`` is a N-dimensional array with shape S=(S_1,...,S_N)
    which holds the labels. The labels should be integer values between
    0 and L-1, where L is the number of labels. ``D`` should be an
    N+1-dimensional array with shape (S_1,...,S_N,L).
    D[p1,...,pn,l] is the unary energy of assigning the label l to the
    variable at the position [p1,...,pn].
    
    ``V`` should be a two-dimensional array (a matrix) with shape (L,L).
    It encodes the binary term. V[l1,l2] is the energy of assigning the
    labels l1 and l2 to neighbor variables. Both ``D`` and ``V`` must be of
    the same type. ``alpha`` indicates the variable that will be expanded
    in this step.
    
    This function modifies the ``labels`` array in-place and
    returns a tuple with the graph used for the step and
    the energy of the cut. Note that the energy of the cut **IS** the
    energy of the labeling, and can be used directly as the criterion
    of convergence.
    """
    return c_aexpansion(alpha, D, V, labels)

def abswap_grid_step(int alpha, int beta, np.ndarray D, np.ndarray V, np.ndarray labels):
    """
    .. note:: Unless you really need to, you should not call this function.
    
    Perform an iteration of the alpha-beta-swap algorithm.
    ``labels`` is a N-dimensional array with shape S=(S_1,...,S_N)
    which holds the labels. The labels should be integer values between
    0 and L-1, where L is the number of labels. ``D`` should be an
    N+1-dimensional array with shape (S_1,...,S_N,L).
    D[p1,...,pn,l] is the unary energy of assigning the label l to the
    variable at the position [p1,...,pn,l].
    
    ``V`` should be a two-dimensional array (a matrix) with shape (L,L).
    It encodes the binary term. V[l1,l2] is the energy of assigning the
    labels l1 and l2 to neighbor variables. Both ``D`` and ``V`` must be of
    the same type. ``alpha`` and ``beta`` are the variables that can be
    swapped in this step.
    
    This function modifies the ``labels`` array in-place and
    returns a tuple with the graph used for the step and
    the energy of the cut. Note that the energy of the cut is **NOT**
    the energy of the labeling, and cannot be used directly as the
    criterion of convergence.
    """
    return c_abswap(alpha, beta, D, V, labels)

cdef extern from "core/graph.h":
    cdef cppclass Graph[T,T,T]:
        Graph(int, int)
        
        void reset()
        
        int add_node(int)
        void add_edge(int, int, T, T) except +
        void add_tweights(int, T, T) except +
        void add_grid_edges(np.ndarray, T) except +
        void add_grid_edges_direction(np.ndarray, T, T, int) except +
        void add_grid_edges_direction_local(np.ndarray, np.ndarray, np.ndarray, int) except +
        void add_grid_tedges(np.ndarray, np.ndarray, np.ndarray) except +
        
        int get_node_num()
        int get_arc_num()
        
        T maxflow()
        
        T what_segment(int) except +
        np.ndarray get_grid_segments(np.ndarray) except +
    

cdef public class GraphInt [object PyObject_GraphInt, type GraphInt]:
    cdef Graph[long, long, long]* thisptr
    def __cinit__(self, int est_node_num=0, int est_edge_num=0):
        """
        ``est_node_num`` gives an estimate of the maximum number of non-terminal
        nodes that can be added to the graph, while ``est_edge_num`` is an
        estimate of the maximum number of non-terminal edges.
        
        It is possible to add more nodes to the graph than est_node_num (and
        node_num_max can be zero). However, if the count is exceeded, then the
        internal memory is reallocated (increased by 50\%), which is expensive.
        Also, temporarily the amount of allocated memory would be more than
        twice than needed. Similarly for edges.
        """
        self.thisptr = new Graph[long, long, long](est_node_num, est_edge_num)
    def __dealloc__(self):
        del self.thisptr
    def reset(self):
        """Remove all nodes and edges."""
        self.thisptr.reset()
    def add_nodes(self, int num_nodes):
        """
        Add non-terminal node(s) to the graph. By default, one node is
        added. If ``num_nodes``>1, then ``num_nodes`` nodes are inserted. It
        returns the identifiers of the nodes added.
        
        The source and terminal nodes are included in the graph by default, and
        you must not add them.
        
        **Important:** see note about the constructor.
        """
        first = self.thisptr.add_node(num_nodes)
        return np.arange(first, first+num_nodes)
    def add_grid_nodes(self, shape):
        """
        Add a grid of non-terminal nodes. Return the identifiers of the added
        nodes in an array with the shape of the grid.
        """
        num_nodes = np.prod(shape)
        first = self.thisptr.add_node(int(num_nodes))
        nodes = np.arange(first, first+num_nodes, dtype=np.int_)
        return np.reshape(nodes, shape)
    def add_edge(self, int i, int j, long capacity, long rcapacity):
        """
        Adds a bidirectional edge between nodes ``i`` and ``j`` with the
        weights ``cap`` and ``rev_cap``.
        
        To add edges between a non-terminal node and terminal nodes, see
        ``add_tedge``.
        
        **Important:** see note about the constructor.
        """
        self.thisptr.add_edge(i, j, capacity, rcapacity)
    def add_tedge(self, int i, long cap_source, long cap_sink):
        """
        Add an edge 'SOURCE->i' with capacity ``cap_source`` and another edge
        'i->SINK' with capacity ``cap_sink``. This method can be called multiple
        times for each node. Capacities can be negative.
        
        **Note:** No internal memory is allocated by this call. The capacities
        of terminal edges are stored as a pair of values in each node.
        """
        self.thisptr.add_tweights(i, cap_source, cap_sink)
    def add_grid_edges(self, np.ndarray nodeids, long capacity):
        """
        Add edges in a grid of non-terminal nodes of the same capacities for
        all the edges. ``capacity`` gives the capacity of all edges.
        
        This is equivalent to call add_edge for many pairs of nodes with the same
        capacity, but much faster.
        
        To add edges between non-terminal nodes and terminal nodes, see
        ``add_grid_tedges``.
        """
        self.thisptr.add_grid_edges(nodeids, capacity)
    def add_grid_edges_direction(self, np.ndarray nodeids, long capacity, long rcapacity, int direction):
        self.thisptr.add_grid_edges_direction(nodeids, capacity, rcapacity, direction)
    def add_grid_edges_direction(self, np.ndarray nodeids, long capacity, int direction):
        self.thisptr.add_grid_edges_direction(nodeids, capacity, capacity, direction)
    def add_grid_edges_direction_local(self, np.ndarray nodeids, np.ndarray capacity, np.ndarray rcapacity, int direction):
        """
        Add edges in a grid of nodes. Each edge will have its own capacity
        and reverse capacity, and all edges will be created along the same
        direction. The array ``capacities`` must have the same shape than
        ``nodeids``, except for the dimension ``direction``, where the
        size must be equal than the size of ``nodeids`` in that dimension - 1.
        
        The capacity given by ``capacities[i_1,...i_d,...,i_n]`` will be
        assigned to the edge between the nodes (i_1,...,i_d,...,i_n) and
        the (i_1,...,i_d+1,...,i_n), where i_d, is the index associated
        to the dimension ``direction``.
        """
        self.thisptr.add_grid_edges_direction_local(nodeids, capacity, rcapacity, direction)
    def add_grid_edges_direction_local(self, np.ndarray nodeids, np.ndarray capacity, int direction):
        """
        This method, provided for convenience, behaves like the previous one.
        In this case the capacities and reverse capacities are equal.
        """
        self.thisptr.add_grid_edges_direction_local(nodeids, capacity, capacity, direction)
    def add_grid_tedges(self, np.ndarray nodeids, np.ndarray sourcecaps, np.ndarray sinkcaps):
        """
        Add terminal edges to a grid of nodes, given their identifiers in
        ``nodeids``. ``sourcecaps`` and ``sinkcaps`` are arrays with the
        capacities of the edges from the source node and to the sink node,
        respectively. The shape of all these arrays must be equal.
        
        This is equivalent to call ``add_tedge`` for many nodes, but much faster.
        """
        self.thisptr.add_grid_tedges(nodeids, sourcecaps, sinkcaps)
    def get_node_num(self):
        """
        Returns the number of non-terminal nodes.
        
        This method is available for backward compatilibity. Use
        ``get_node_count`` instead.
        """
        return self.thisptr.get_node_num()
    def get_edge_num(self):
        """
        Returns the number of non-terminal edges.
        
        This method is available for backward compatilibity. Use
        ``get_edge_count`` instead.
        """
        return self.thisptr.get_arc_num()
    def get_node_count(self):
        """Returns the number of non-terminal nodes."""
        return self.thisptr.get_node_num()
    def get_edge_count(self):
        """Returns the number of non-terminal edges."""
        return self.thisptr.get_arc_num()
    def maxflow(self):
        """
        Perform the maxflow computation in the graph. Returns the capacity of
        the minimum cut or, equivalently, the maximum flow of the graph.
        """
        return self.thisptr.maxflow()
    def get_segment(self, i):
        """Returns which segment the given node belongs to."""
        return self.thisptr.what_segment(i)
    def get_grid_segments(self, np.ndarray nodeids):
        """
        After the maxflow is computed, this function returns which
        segment the given nodes belong to. The output is a boolean array
        of the same shape than the input array ``nodeids``.
        
        This is equivalent to call ``get_segment`` for many nodes, but much faster.
        """
        return self.thisptr.get_grid_segments(nodeids)

cdef public class GraphFloat [object PyObject_GraphFloat, type GraphFloat]:
    cdef Graph[double, double, double]* thisptr
    def __cinit__(self, int est_node_num=0, int est_edge_num=0):
        """
        ``est_node_num`` gives an estimate of the maximum number of non-terminal
        nodes that can be added to the graph, while ``est_edge_num`` is an
        estimate of the maximum number of non-terminal edges.
        
        It is possible to add more nodes to the graph than est_node_num (and
        node_num_max can be zero). However, if the count is exceeded, then the
        internal memory is reallocated (increased by 50\%), which is expensive.
        Also, temporarily the amount of allocated memory would be more than
        twice than needed. Similarly for edges.
        """
        self.thisptr = new Graph[double, double, double](est_node_num, est_edge_num)
    def __dealloc__(self):
        del self.thisptr
    def reset(self):
        """Remove all nodes and edges."""
        self.thisptr.reset()
    def add_nodes(self, int num_nodes):
        """
        Add non-terminal node(s) to the graph. By default, one node is
        added. If ``num_nodes``>1, then ``num_nodes`` nodes are inserted. It
        returns the identifiers of the nodes added.
        
        The source and terminal nodes are included in the graph by default, and
        you must not add them.
        
        **Important:** see note about the constructor"""
        first = self.thisptr.add_node(num_nodes)
        return np.arange(first, first+num_nodes)
    def add_grid_nodes(self, shape):
        """
        Add a grid of non-terminal nodes. Return the identifiers of the added
        nodes in an array with the shape of the grid.
        """
        num_nodes = np.prod(shape)
        first = self.thisptr.add_node(int(num_nodes))
        nodes = np.arange(first, first+num_nodes, dtype=np.int_)
        return np.reshape(nodes, shape)
    def add_edge(self, int i, int j, double capacity, double rcapacity):
        """
        Adds a bidirectional edge between nodes ``i`` and ``j`` with the
        weights ``cap`` and ``rev_cap``.
        
        To add edges between a non-terminal node and terminal nodes, see
        ``add_tedge``.
        
        **Important:** see note about the constructor.
        """
        self.thisptr.add_edge(i, j, capacity, rcapacity)
    def add_tedge(self, int i, double cap_source, double cap_sink):
        """
        Add an edge 'SOURCE->i' with capacity ``cap_source`` and another edge
        'i->SINK' with capacity ``cap_sink``. This method can be called multiple
        times for each node. Capacities can be negative.
        
        **Note:** No internal memory is allocated by this call. The capacities
        of terminal edges are stored as a pair of values in each node.
        """
        self.thisptr.add_tweights(i, cap_source, cap_sink)
    def add_grid_edges(self, np.ndarray nodeids, double capacity):
        """
        Add edges in a grid of non-terminal nodes of the same capacities for
        all the edges. ``capacity`` gives the capacity of all edges.
        
        This is equivalent to call add_edge for many pairs of nodes with the same
        capacity, but much faster.
        
        To add edges between non-terminal nodes and terminal nodes, see
        ``add_grid_tedges``.
        """
        self.thisptr.add_grid_edges(nodeids, capacity)
    def add_grid_edges_direction(self, np.ndarray nodeids, double capacity, double rcapacity, int direction):
        self.thisptr.add_grid_edges_direction(nodeids, capacity, rcapacity, direction)
    def add_grid_edges_direction(self, np.ndarray nodeids, double capacity, int direction):
        self.thisptr.add_grid_edges_direction(nodeids, capacity, capacity, direction)
    def add_grid_edges_direction_local(self, np.ndarray nodeids, np.ndarray capacity, np.ndarray rcapacity, int direction):
        """
        Add edges in a grid of nodes. Each edge will have its own capacity
        and reverse capacity, and all edges will be created along the same
        direction. The array ``capacities`` must have the same shape than
        ``nodeids``, except for the dimension ``direction``, where the
        size must be equal than the size of ``nodeids`` in that dimension - 1.
        
        The capacity given by ``capacities[i_1,...i_d,...,i_n]`` will be
        assigned to the edge between the nodes (i_1,...,i_d,...,i_n) and
        the (i_1,...,i_d+1,...,i_n), where i_d, is the index associated
        to the dimension ``direction``.
        """
        self.thisptr.add_grid_edges_direction_local(nodeids, capacity, rcapacity, direction)
    def add_grid_edges_direction_local(self, np.ndarray nodeids, np.ndarray capacity, int direction):
        """
        This method, provided for convenience, behaves like the previous one.
        In this case the capacities and reverse capacities are equal.
        """
        self.thisptr.add_grid_edges_direction_local(nodeids, capacity, capacity, direction)
    def add_grid_tedges(self, np.ndarray nodeids, np.ndarray sourcecaps, np.ndarray sinkcaps):
        """
        Add terminal edges to a grid of nodes, given their identifiers in
        ``nodeids``. ``sourcecaps`` and ``sinkcaps`` are arrays with the
        capacities of the edges from the source node and to the sink node,
        respectively. The shape of all these arrays must be equal.
        
        This is equivalent to call ``add_tedge`` for many nodes, but much faster.
        """
        self.thisptr.add_grid_tedges(nodeids, sourcecaps, sinkcaps)
    def get_node_num(self):
        """
        Returns the number of non-terminal nodes.
        
        This method is available for backward compatilibity. Use
        ``get_node_count`` instead.
        """
        return self.thisptr.get_node_num()
    def get_edge_num(self):
        """
        Returns the number of non-terminal edges.
        
        This method is available for backward compatilibity. Use
        ``get_edge_count`` instead.
        """
        return self.thisptr.get_arc_num()
    def get_node_count(self):
        """Returns the number of non-terminal nodes."""
        return self.thisptr.get_node_num()
    def get_edge_count(self):
        """Returns the number of non-terminal edges."""
        return self.thisptr.get_arc_num()
    def maxflow(self):
        """
        Perform the maxflow computation in the graph. Returns the capacity of
        the minimum cut or, equivalently, the maximum flow of the graph.
        """
        return self.thisptr.maxflow()
    def get_segment(self, i):
        """Returns which segment the given node belongs to."""
        return self.thisptr.what_segment(i)
    def get_grid_segments(self, np.ndarray nodeids):
        """
        After the maxflow is computed, this function returns which
        segment the given nodes belong to. The output is a boolean array
        of the same shape than the input array ``nodeids``.
        
        This is equivalent to call ``get_segment`` for many nodes, but much faster.
        """
        return self.thisptr.get_grid_segments(nodeids)
