import importlib.util
import os
import sys

from cpyte.extension_hooks import CodegenHook, HookMetadata

try:
    import llvmlite.ir as ir
except Exception:  # pragma: no cover
    ir = None

try:
    from cpyte.errors import CompileError
except Exception:  # pragma: no cover
    CompileError = Exception


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


def _i32c(v):
    return ir.Constant(ir.IntType(32), v)


def _i64c(v):
    return ir.Constant(ir.IntType(64), v)


# (name, arg ir types, ret ir type) — runtime helpers this hook guarantees.
_HELPERS = [
    ("cpy_async_task_spawn", [ir.IntType(8).as_pointer(), ir.IntType(8).as_pointer(), ir.IntType(8).as_pointer(), ir.IntType(64)], ir.IntType(8).as_pointer()),
    ("cpy_async_await", [ir.IntType(8).as_pointer()], ir.IntType(64)),
    ("cpy_async_task_set_result", [ir.IntType(64)], ir.VoidType()),
    ("cpy_async_arg_i32", [ir.IntType(8).as_pointer(), ir.IntType(64)], ir.IntType(64)),
    ("cpy_async_arg_i64", [ir.IntType(8).as_pointer(), ir.IntType(64)], ir.IntType(64)),
    ("cpy_async_arg_f64", [ir.IntType(8).as_pointer(), ir.IntType(64)], ir.DoubleType()),
    ("cpy_async_arg_ptr", [ir.IntType(8).as_pointer(), ir.IntType(64)], ir.IntType(8).as_pointer()),
]


def _declare_function(llvm, name, arg_tys, ret_ty):
    existing = llvm.functions.get(name)
    if existing is not None and isinstance(existing, ir.Function):
        return existing
    fn = ir.Function(llvm.module, ir.FunctionType(ret_ty, arg_tys), name=name)
    llvm.functions[name] = fn
    return fn


# DynValue kinds (mirror bytecoding/runtime.c)
_DYN_INT = 1
_DYN_INT64 = 2
_DYN_UINT64 = 3
_DYN_CHAR = 4
_DYN_BOOL = 5
_DYN_DOUBLE = 6
_DYN_PTR = 9


def _kind_for(param_type: str) -> int:
    if param_type == "bool":
        return _DYN_BOOL
    if param_type == "char":
        return _DYN_CHAR
    if param_type == "int64":
        return _DYN_INT64
    if param_type in ("uint64", "size_t"):
        return _DYN_UINT64
    if param_type in ("float", "double"):
        return _DYN_DOUBLE
    if param_type == "int":
        return _DYN_INT
    return _DYN_PTR  # pointers, str, big, ubig, structs, dynamic


class AsyncCodegenHook(CodegenHook):
    def __init__(self):
        super().__init__(
            "asyncio_ext",
            metadata=HookMetadata(
                name="asyncio_ext_codegen",
                version="2.0.0",
                description=(
                    "emits an `async def` wrapper that boxes args, spawns a "
                    "fiber task and runs the lowered body"
                ),
            ),
        )

    def should_emit_node(self, node):
        return isinstance(node, AsyncFuncDefNode)

    def emit_node(self, node, builder, context):
        llvm = context.data["llvm"]
        module = llvm.module
        dyn_value = _DynValue = ir.LiteralStructType([ir.IntType(32), ir.IntType(64)])
        old_builder = llvm.builder

        for name, arg_tys, ret_ty in _HELPERS:
            _declare_function(llvm, name, arg_tys, ret_ty)

        # External global holding the current loop (runtime C defines it).
        loop_g = llvm.module.globals.get("__asyncio_loop")
        if loop_g is None:
            loop_g = ir.GlobalVariable(module, ir.IntType(8).as_pointer(), "__asyncio_loop")

        # Emit the fiber body (named foo_async_body(void* argv) -> void).
        llvm.emit_funcdef(node.body_def)

        # Emit the public wrapper: same params, returns the task future.
        param_tys = [llvm.llvm_type(t) for t in node.wrapper_def.params.values()]
        fnty = ir.FunctionType(
            ir.IntType(8).as_pointer(), param_tys, var_arg=False
        )
        wrapper = ir.Function(module, fnty, name=node.wrapper_def.name)
        llvm.functions[node.wrapper_def.name] = wrapper

        entry = wrapper.append_basic_block("entry")
        llvm.builder = ir.IRBuilder(entry)
        b = llvm.builder
        b.position_at_end(entry)

        zero = _i32c(0)
        one = _i32c(1)

        loopv = b.load(loop_g)

        argc = len(node.wrapper_def.params)
        argv_alloca = b.alloca(ir.ArrayType(dyn_value, argc))
        for i, (pname, ptype) in enumerate(node.wrapper_def.params.items()):
            slot = b.gep(argv_alloca, [zero, _i32c(i)])
            kind_ptr = b.gep(slot, [zero, zero])
            b.store(_i32c(_kind_for(ptype)), kind_ptr)
            data_ptr = b.gep(slot, [zero, one])
            arg = wrapper.args[i]
            arg_ty = arg.type
            if isinstance(arg_ty, ir.IntType):
                if arg_ty.width == 64:
                    data = arg
                elif arg_ty.width < 64:
                    data = b.zext(arg, ir.IntType(64))
                else:
                    data = b.trunc(arg, ir.IntType(64))
            elif isinstance(arg_ty, ir.DoubleType):
                data = b.bitcast(arg, ir.IntType(64))
            elif isinstance(arg_ty, ir.PointerType):
                data = b.ptrtoint(arg, ir.IntType(64))
            else:
                from cpyte.errors import CompileError

                raise CompileError(
                    f"async task param `{pname}`: unsupported type `{ptype}` "
                    "(fiber boxing supports int/int64/uint64/double/pointers)"
                )
            b.store(data, data_ptr)

        body_fn = llvm.functions.get(node.body_def.name)
        if body_fn is None:
            raise CompileError(f"async body `{node.body_def.name}` was not emitted")
        argv_ptr = b.bitcast(argv_alloca, ir.IntType(8).as_pointer())
        body_ptr = b.bitcast(body_fn, ir.IntType(8).as_pointer())
        spawn = llvm.functions.get("cpy_async_task_spawn")
        res = b.call(
            spawn,
            [loopv, body_ptr, argv_ptr, _i64c(argc)],
        )
        b.ret(res)

        llvm.builder = old_builder
        return res


hook = AsyncCodegenHook()


def get_hooks():
    return [hook]