import importlib.util
import os
import sys

from cpyte.extension_hooks import HookMetadata, ParserHook

try:
    from cpyte.astparse import Call, Variable, parse_def
    from cpyte.lexar import TokenType
except Exception:  # pragma: no cover - import guard
    Call = None
    TokenType = None


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


class AsyncParserHook(ParserHook):
    def __init__(self):
        super().__init__(
            "asyncio_ext",
            metadata=HookMetadata(
                name="asyncio_ext_parser",
                version="2.0.0",
                description=(
                    "parses `async def` (top-level) into wrapper+body defs and "
                    "lowers `await e` to cpy_async_await(e)"
                ),
            ),
        )

    # ------------------------------------------------------------------
    # `await <expr>` → cpy_async_await(<expr>)
    # ------------------------------------------------------------------
    def should_handle_expression(self, tokens, pos):
        if pos >= len(tokens):
            return False
        tok = tokens[pos]
        return tok.type == TokenType.KEYWORD and tok.value == "await"

    def parse_expression(self, tokens, pos, ctx=None):
        tok = tokens[pos]
        pos += 1
        if pos >= len(tokens):
            from cpyte.astparse import ParseError

            raise ParseError("Expected expression after `await`", tok)
        inner, pos = ctx.data["astparse"].parse_expression(tokens, pos)
        return Call(Variable("cpy_async_await"), [inner], token=tok), pos

    # ------------------------------------------------------------------
    # `async [public] def foo(...) -> T:`
    # ------------------------------------------------------------------
    def should_handle_statement(self, tokens, pos):
        if pos >= len(tokens):
            return False
        tok = tokens[pos]
        if tok.type != TokenType.KEYWORD or tok.value != "async":
            return False
        i = pos + 1
        while i < len(tokens) and tokens[i].type == TokenType.IDENTIFIER and tokens[i].value in ("public", "private", "internal"):
            i += 1
        return (
            i < len(tokens)
            and tokens[i].type == TokenType.KEYWORD
            and tokens[i].value == "def"
        )

    def parse_statement(self, tokens, pos, ctx=None):
        tok = tokens[pos]
        i = pos + 1
        visibility = None
        while i < len(tokens) and tokens[i].type == TokenType.IDENTIFIER and tokens[i].value in ("public", "private", "internal"):
            if tokens[i].value == "public":
                visibility = "public"
            i += 1
        wrapper, def_end = parse_def(tokens, i)
        wrapper.visibility = visibility or "public"
        node = _NODES.build_async_node(wrapper, tok)
        return node, def_end


hook = AsyncParserHook()


def get_hooks():
    return [hook]