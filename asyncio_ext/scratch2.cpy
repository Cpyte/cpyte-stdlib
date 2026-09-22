import @std/asyncio_ext

public main() -> int:
    void* loop = loop_new()
    print("A")
    void* timer = sleep(loop, 1)
    print("B")
    print(ready(timer))
    print("C")
    print(run(loop, timer))
    print("D")
    print(ready(timer))
    print("E")
    print(result(timer))
    print("F")
    loop_free(loop)
    print("G")
    return 0
