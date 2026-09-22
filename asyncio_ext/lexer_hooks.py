from cpyte.extension_hooks import HookMetadata, LexerHook


class AsyncAwaitLexerHook(LexerHook):
    def get_new_keywords(self):
        return {"async", "await"}

def get_hooks():
    return [
        AsyncAwaitLexerHook(
            "asyncio_ext",
            metadata=HookMetadata(
                name="asyncio_ext_lexer",
                version="1.0.0",
                description="Registers async/await language keywords",
            ),
        )
    ]
