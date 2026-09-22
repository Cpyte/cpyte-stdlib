import @std/asyncio_ext

async def timer_tick(ms int, tag int) -> int:
    void* t = sleep(current_loop(), ms)
    int64 r = await t
    print(tag)
    return tag

public main() -> int:
    void* loop = loop_new()
    void* a = timer_tick(2, 1)
    void* b = timer_tick(1, 2)
    void* c = timer_tick(3, 3)
    print(run(loop, c))
    print(result(a))
    print(result(b))
    print(result(c))
    loop_free(loop)
    return 0