import importlib.util
import os
import sys

try:
    from cpyte.astparse import Call
    from cpyte.semantic_analasis import Symbol
except Exception:  # pragma: no cover
    Call = None
from cpyte.extension_hooks import HookMetadata, SemanticHook


def _shared():
    """Load the fixed-name shared nodes module exactly once per process."""
    name = "cpyte_asyncio_nodes"
    if name in sys.modules:
        return sys.modules[name]
    here = os.path.dirname(os.path.abspath(__file__))
    spec = importlib.util.spec_from_file_location(name, os.path.join(here, "asyncio_nodes.py"))
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


_NODES = _shared()
AsyncFuncDefNode = _NODES.AsyncFuncDefNode


# (name, ret, params) — signatures of the fiber runtime helpers the codegen
# hook will declare as externs. Semantic treats them as builtin_func (no extra
# arg-count check); codegen owns the real calling convention.
EXTERNS = [
    ("cpy_async_task_spawn", "void*", ["void*", "void*", "void*", "long long"]),
    ("cpy_async_await", "int64", ["void*"]),
    ("cpy_async_task_set_result", "void", ["long long"]),
    ("cpy_async_arg_i32", "long long", ["void*", "long long"]),
    ("cpy_async_arg_i64", "long long", ["void*", "long long"]),
    ("cpy_async_arg_f64", "double", ["void*", "long long"]),
    ("cpy_async_arg_ptr", "void*", ["void*", "long long"]),
]


class AsyncSemanticHook(SemanticHook):
    def __init__(self):
        super().__init__(
            "asyncio_ext",
            metadata=HookMetadata(
                name="asyncio_ext_semantic",
                version="2.0.0",
                description=(
                    "registers async/await runtime helpers and typechecks "
                    "the fiber body of `async def`"
                ),
            ),
        )

    def should_visit_node(self, node):
        return isinstance(node, AsyncFuncDefNode)

    def visit_node(self, node, context=None):
        if context is None:
            return []
        analyzer = context.data.get("analyzer")
        scope = context.data.get("scope") or getattr(analyzer, "globals", None)
        if analyzer is None or scope is None:
            return []

        for name, ret, _params in EXTERNS:
            if scope.lookup(name) is None:
                scope.define(name, Symbol("builtin_func", ret, None, initialized=True))

        if scope.lookup(node.name) is None:
            wrapper_sym = Symbol("function", "void*", node.wrapper_def, initialized=True)
            scope.define(node.name, wrapper_sym)

        try:
            # Typecheck the fiber body now that wrapper + helpers are in scope.
            analyzer._visit_funcdef(node.body_def, scope)
        except Exception:
            pass
        return []


hook = AsyncSemanticHook()


def get_hooks():
    return [hook]