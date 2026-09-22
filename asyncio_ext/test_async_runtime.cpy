import @std/asyncio_ext

public main() -> int:
    void* loop = loop_new()
    void* timer = sleep(loop, 1)
    print(ready(timer))
    print(run(loop, timer))
    print(ready(timer))
    print(result(timer))
    loop_free(loop)
    return 0
