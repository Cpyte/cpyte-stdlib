"""Shared node/helper module for the asyncio_ext hook files.

Hook files are loaded by cpyte as standalone modules under unstable names, so
relative imports would create multiple class identities and break isinstance
checks. This module is exec'd once under the *fixed* name `cpyte_asyncio_nodes`
and reused by all three hooks, guaranteeing a single `AsyncFuncDefNode`.
"""

try:
    from cpyte.astparse import (
        Call,
        FuncDef,
        If,
        Number,
        Return,
        VarDecl,
        Variable,
        While,
    )
except Exception:  # pragma: no cover - import guard
    Call = None


class AsyncFuncDefNode:
    """`async def foo(...) -> T:` — a function whose body runs in a fiber.

    Holds two real FuncDefs: `wrapper_def` (the public `foo`, same params,
    returns a `void*` task future) and `body_def` (`foo_async_body(void* argv)
    -> void`, where params are unboxed from the boxed DynValue array and
    `return e` becomes `cpy_async_task_set_result(e); return;`).
    """

    __slots__ = ("_token", "body_def", "name", "params", "rettype", "wrapper_def")

    def __init__(self, wrapper_def, body_def):
        self.wrapper_def = wrapper_def
        self.body_def = body_def
        self.name = wrapper_def.name
        self.params = wrapper_def.params
        self.rettype = wrapper_def.rettype
        self._token = wrapper_def._token

    def __repr__(self):
        return f"AsyncFuncDefNode({self.name})"


def _box_arg_helper(param_type: str):
    if param_type in ("int", "bool", "char") or param_type.startswith(("int32", "int8", "int16")):
        return "cpy_async_arg_i32"
    if param_type in ("int64", "uint64", "size_t", "long", "unsigned", "long long", "short"):
        return "cpy_async_arg_i64"
    if param_type in ("float", "double"):
        return "cpy_async_arg_f64"
    if param_type == "dynamic":
        return "cpy_async_arg_i64"
    return "cpy_async_arg_ptr"  # pointers, str, big, ubig, structs


def unbox_var_decls(params):
    decls = []
    for i, (pname, ptype) in enumerate(params.items()):
        helper = _box_arg_helper(ptype)
        call = Call(Variable(helper), [Variable("argv"), Number(str(i), None)])  # pyright: ignore[reportPossiblyUnboundVariable, reportOptionalCall]
        if ptype in ("int", "bool", "char"):
            from cpyte.astparse import CastExpr

            call = CastExpr(ptype, call)
        decls.append(VarDecl(pname, ptype, init=call)) # pyright: ignore[reportPossiblyUnboundVariable]
    return decls


def lower_return(stmt):
    """Rewrite `return e` into `cpy_async_task_set_result(e); return;`.

    Deep-walks block statements (if/elif/else, while) and rewrites in place.
    """
    if isinstance(stmt, Return) and stmt.value is not None: # pyright: ignore[reportPossiblyUnboundVariable, reportOptionalCall]
        call = Call(Variable("cpy_async_task_set_result"), [stmt.value], token=stmt._token) # pyright: ignore[reportPossiblyUnboundVariable, reportOptionalCall]
        from cpyte.astparse import ExprStmt

        return [ExprStmt(call, token=stmt._token), Return(None, token=stmt._token)] # pyright: ignore[reportPossiblyUnboundVariable, reportOptionalCall]
    if isinstance(stmt, If): # pyright: ignore[reportPossiblyUnboundVariable, reportOptionalCall]
        stmt.body = [
            s for inner in (lower_return(s) for s in stmt.body) for s in inner
        ]
        if stmt.orelse is not None:
            stmt.orelse = [
                s
                for inner in (lower_return(s) for s in stmt.orelse)
                for s in inner
            ]
        return [stmt]
    if isinstance(stmt, While): # pyright: ignore[reportPossiblyUnboundVariable, reportOptionalCall]
        stmt.body = [
            s for inner in (lower_return(s) for s in stmt.body) for s in inner
        ]
        return [stmt]
    return [stmt]


def build_async_node(wrapper, tok):
    """Given the parsed `async def` FuncDef, produce the AsyncFuncDefNode."""
    wrapper.visibility = wrapper.visibility or "public"
    wrapper.rettype = wrapper.rettype or "void"

    body_statements = []
    for s in wrapper.body:
        body_statements.extend(lower_return(s))

    body_def = FuncDef( # pyright: ignore[reportPossiblyUnboundVariable, reportOptionalCall]
        wrapper.name + "_async_body",
        {"argv": "void*"},
        (unbox_var_decls(wrapper.params) + body_statements),
        "void",
        visibility="internal",
        generic_params=wrapper.generic_params,
        const_params=wrapper.const_params,
        token=tok,
    )
    wrapper.body = []
    return AsyncFuncDefNode(wrapper, body_def)
