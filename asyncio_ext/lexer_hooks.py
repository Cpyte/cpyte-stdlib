from cpyte.extension_hooks import HookMetadata, LexerHook


class AsyncAwaitLexerHook(LexerHook):
    def get_additional_keywords(self):
        return {"async", "await"}

    # Pre-context API name, kept as an alias for older tools that call it
    # directly. The compiler dispatcher uses get_additional_keywords().
    def get_new_keywords(self):
        return self.get_additional_keywords()

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
