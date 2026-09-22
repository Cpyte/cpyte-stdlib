import @std/asyncio_ext

public main() -> int:
    print("A")
    void* loop = loop_new()
    print("B")
    void* timer = sleep(loop, 1)
    print("C")
    print(ready(timer))
    print("D")
    print(run(loop, timer))
    print("E")
    print(ready(timer))
    print("F")
    print(result(timer))
    print("G")
    loop_free(loop)
    print("H")
    return 0