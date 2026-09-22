import @std/asyncio_ext

async def add(a int, b int) -> int:
    return a + b

async def square(x int) -> int:
    return x * x

public main() -> int:
    void* loop = loop_new()
    void* fut = add(3, 4)
    print(run(loop, fut))
    print(result(fut))
    void* fut2 = square(9)
    print(run(loop, fut2))
    print(result(fut2))
    loop_free(loop)
    return 0