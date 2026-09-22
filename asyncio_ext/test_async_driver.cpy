import @std/asyncio_ext

async def compute(x int) -> int:
    return x * x

async def driver(n int) -> int:
    int total = 0
    int i = 0
    while i < n:
        void* t = compute(i)
        int64 r = await t
        total = total + (int)r
        i = i + 1
    return total

public main() -> int:
    void* loop = loop_new()
    void* d = driver(5)
    print(run(loop, d))
    print(result(d))
    loop_free(loop)
    return 0