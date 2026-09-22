ccode:
    extern void* cpy_async_loop_new(void);
    extern void* cpy_async_current_loop(void);
    extern void cpy_async_loop_stop(void*);
    extern void cpy_async_loop_free(void*);
    extern void* cpy_async_sleep(void*, long long);
    extern void* cpy_async_fd_wait(void*, int, int, long long);
    extern int cpy_async_loop_run(void*, void*);
    extern int cpy_async_future_ready(void*);
    extern int cpy_async_future_cancel(void*);
    extern long long cpy_async_future_result(void*);
    extern int cpy_async_future_state(void*);

public loop_new() -> void*:
    return cpy_async_loop_new()

public loop_stop(loop void*) -> int:
    cpy_async_loop_stop(loop)
    return 0

public loop_free(loop void*) -> int:
    cpy_async_loop_free(loop)
    return 0

public sleep(loop void*, delay_ms int64) -> void*:
    return cpy_async_sleep(loop, delay_ms)

public wait_fd(loop void*, fd int, events int, timeout_ms int64) -> void*:
    return cpy_async_fd_wait(loop, fd, events, timeout_ms)

public run(loop void*, future void*) -> int:
    return cpy_async_loop_run(loop, future)

public ready(future void*) -> int:
    return cpy_async_future_ready(future)

public cancel(future void*) -> int:
    return cpy_async_future_cancel(future)

public result(future void*) -> int64:
    return cpy_async_future_result(future)

public state(future void*) -> int:
    return cpy_async_future_state(future)
public current_loop() -> void*:
    return cpy_async_current_loop()
