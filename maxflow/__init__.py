# -*- encoding:utf-8 -*-

"""
maxflow
=======

``maxflow`` is a Python module for max-flow/min-cut computations. It wraps
the C++ maxflow library by Vladimir Kolmogorov, which implements the
algorithm described in

        An Experimental Comparison of Min-Cut/Max-Flow Algorithms for Energy
        Minimization in Vision. Yuri Boykov and Vladimir Kolmogorov. TPAMI.

This module aims to simplifying the construction of graphs with complex
layouts. It provides two Graph classes, ``Graph[int]`` and ``Graph[float]``,
for integer and real data types.

Example:

>>> g = maxflow.Graph[int](2, 2)
>>> g.add_nodes(2)
0
>>> g.add_edge(0, 1, 1, 2)
>>> g.add_tedge(0, 2, 5)
>>> g.add_tedge(1, 9, 4)
>>> g.maxflow()
8
>>> g.get_segments()
array([ True, False], dtype=bool)

If you use this library for research purposes, you **MUST** cite the
aforementioned paper in any resulting publication
"""

import numpy as np
import _maxflow
from _maxflow import GraphInt, GraphFloat
from version import __version__, __version_str__, \
        __version_core__, __author__, __author_core__

Graph = {int:GraphInt, float:GraphFloat}
