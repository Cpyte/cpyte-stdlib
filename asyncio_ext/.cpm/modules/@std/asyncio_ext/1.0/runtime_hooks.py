from cpyte.extension_hooks import HookMetadata, RuntimeHook


class AsyncRuntimeHook(RuntimeHook):
    def __init__(self):
        super().__init__(
            "asyncio_ext",
            metadata=HookMetadata(
                name="asyncio_ext_runtime",
                version="2.1.0",
                description=(
                    "cross-platform fiber event loop: timers, fd readiness, "
                    "tasks, await/commit model (ucontext / Windows Fibers / "
                    "asm switch)"
                ),
            ),
        )

    def get_runtime_code(self, context=None):
        return r"""
/* ============================================================================
 * asyncio_ext fiber event-loop runtime (single-threaded, cooperative).
 *
 * FUTURES (handles). A future is an opaque handle allocated by the loop and
 * handed to the caller; it is the completion token `await` (and the
 * `run(loop, future)` driver) consumes. It is a handle, not the value itself:
 * the value is read later via future_result(), and a future stays valid until
 * loop_free() regardless of who resolved it.
 *
 * Every future has exactly one of four states: PENDING, DONE, CANCELLED or
 * FAILED, and single-waiter semantics: at most one fiber may be blocked on it
 * at a time, and a second `await` on a PENDING future that already has a
 * waiter is a fatal error (the runtime aborts with a clear message). Awaiting
 * an already-completed future returns its result immediately without
 * suspending.
 *
 * There are three kinds of future:
 *   - timer futures  -- created by sleep(loop, delay_ms). They complete DONE
 *     with result 0 once the monotonic clock passes the absolute deadline
 *     (now_ms + delay_ms) captured at creation, whether or not a fiber is
 *     awaiting them. Timers are kept in a list sorted by deadline, so the
 *     loop always knows exactly how long it may block.
 *   - fd futures     -- created by wait_fd(loop, fd, events, timeout_ms).
 *     They register `fd` as a poll()/WSAPoll() watcher for the requested
 *     event bits (ASYNC_EV_READ/WRITE/...; the values are the same on every
 *     platform, see below) and complete DONE with the observed readiness
 *     bitmask as the result when any requested event fires, or DONE with
 *     result 0 when the optional timeout expires first. fd futures can only
 *     be created while the loop is not running.
 *   - task futures   -- created implicitly by spawning a task (every
 *     `async def` call schedules one). They complete when the task's body
 *     finishes: DONE with the task's return value, or FAILED if the fiber
 *     aborted. A task future is created on spawn, so a caller can `await`
 *     it or hand it to run() before the task has even started.
 *
 * THE LOOP. run(loop, until) pumps the event loop until `until` completes
 * (or the loop is stopped via loop_stop()). Each iteration:
 *   1. runs every READY fiber to its next suspension point (an `await`) or to
 *      completion;
 *   2. when no fiber is runnable, advances timers whose deadline has passed;
 *   3. otherwise blocks in poll()/WSAPoll() (or a plain sleep when only
 *      timers are pending) until the earliest deadline or fd activity, then
 *      re-checks timers.
 * `await future` registers the CURRENT fiber as the future's single waiter,
 * marks the fiber WAITING and switches back to the loop; only completing the
 * future moves the fiber to READY and back through run(). When the run()
 * target itself completes the loop stops and returns its final state. Nested
 * run() calls on one loop are a fatal error; the runtime is single-threaded
 * and cooperative, so there is exactly one actively running fiber at any
 * instant.
 *
 * PLATFORMS. The runtime is not POSIX-only; the scheduler is hosted on any
 * of three backends selected automatically at compile time from the
 * preprocessor macros of the build environment:
 *   - Windows (_WIN32): the native Windows Fibers API. The thread converts
 *     once at run() (ConvertThreadToFiber) and task stacks are created with
 *     CreateFiber; switches use SwitchToFiber; completed fibers are released
 *     with DeleteFiber. Timers use GetTickCount64(), sleeps use Sleep(), and
 *     fd readiness uses WSAPoll(). Event bits are translated between the
 *     canonical values below and the winsock POLL* constants, so the cpy
 *     API is identical on Windows and POSIX.
 *   - POSIX ucontext: macOS, *BSD, musl and glibc < 2.34.5 provide
 *     getcontext/makecontext/swapcontext, so an async body keeps its real C
 *     stack and locals, loops and recursion just work.
 *   - asm switch: glibc >= 2.34 REMOVED the ucontext family, so on Linux
 *     new enough that <ucontext.h> is gone the runtime uses a small
 *     callee-saved-register stack switcher written in assembly (x86-64 SysV
 *     and AArch64) with identical semantics: a fiber is a fresh stack whose
 *     top is framed so the first switch RETs into the tramp, and every
 *     suspend/resume pair saves and restores the full callee-saved set.
 *
 * The public C API below is identical on every platform; the backend choice
 * is an implementation detail.
 * ========================================================================== */

#if defined(_WIN32)
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0600
#endif
#include <winsock2.h>
#include <windows.h>
#include <ws2tcpip.h>
#pragma comment(lib, "ws2_32.lib")
#define ASYNC_BACKEND_WIN 1
#else
#if defined(__APPLE__) && !defined(_XOPEN_SOURCE)
#define _XOPEN_SOURCE 600
#endif
#include <errno.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
/* Backend selection. Only OBJECT macros may appear in the #if expressions
 * below: some clang builds (Apple) parse the whole expression eagerly and an
 * undefined function-like macro call -- e.g. !__GLIBC_PREREQ(2, 34) -- is a
 * hard "token is not a valid binary operator" error even behind a false
 * short-circuit. Undefined object-macros simply evaluate to 0. */
#if defined(__GLIBC__) && (__GLIBC__ * 100 + __GLIBC_MINOR__) >= 234
/* glibc >= 2.34 removed the ucontext family; use the asm stack switcher. */
#define ASYNC_BACKEND_ASM 1
#if !defined(__x86_64__) && !defined(__aarch64__)
#error "asyncio_ext: asm fiber switcher has no implementation for this architecture"
#endif
#else
/* macOS, *BSD, musl and glibc < 2.34: getcontext/makecontext/swapcontext. */
#define ASYNC_BACKEND_UCONTEXT 1
#endif
#if defined(ASYNC_BACKEND_UCONTEXT)
#include <ucontext.h>
#endif
#endif

#define ASYNC_STATE_PENDING 0
#define ASYNC_STATE_DONE 1
#define ASYNC_STATE_CANCELLED 2
#define ASYNC_STATE_FAILED 3

#define ASYNC_FIBER_NEW 0
#define ASYNC_FIBER_READY 1
#define ASYNC_FIBER_RUNNING 2
#define ASYNC_FIBER_WAIT 3
#define ASYNC_FIBER_DONE 4

#define ASYNC_STACK_SIZE (512 * 1024)

/* Canonical fd event bits: identical on every platform. The values match the
 * POSIX poll(2) constants so POSIX builds need no translation; on Windows the
 * watchers translate to/from the winsock POLL* bits (POLLIN/POLLPRI/POLLOUT/
 * POLLERR/POLLHUP). */
#define ASYNC_EV_READ 0x0001
#define ASYNC_EV_PRI 0x0002
#define ASYNC_EV_WRITE 0x0004
#define ASYNC_EV_ERR 0x0008
#define ASYNC_EV_HUP 0x0010

/* Match the cpyte runtime DynValue {int kind; uint64_t data;} (16 bytes). */
typedef struct {
    int kind;
    uint64_t data;
} DynValue;

typedef struct cpy_async_fiber cpy_async_fiber;
typedef struct cpy_async_loop cpy_async_loop;

typedef struct cpy_async_future {
    cpy_async_loop *loop;
    int state;                 /* pending / done / cancelled / failed */
    int64_t result;
    int64_t deadline_ms;       /* -1 none (timers + fd timeouts) */
    int fd;                    /* -1 none */
    short events;
    cpy_async_fiber *waiter;   /* the single fiber awaiting this future */
    struct cpy_async_future *next;
} cpy_async_future;

struct cpy_async_fiber {
#if ASYNC_BACKEND_WIN
    void *fiber;               /* CreateFiber handle (owns the task stack) */
#elif ASYNC_BACKEND_UCONTEXT
    ucontext_t ctx;
    int ctx_init;
#else
    void *sp;                  /* saved stack pointer */
#endif
    char *stack;               /* NULL on Windows (CreateFiber owns it) */
    size_t stack_size;
    int state;
    void (*entry)(void *argv);
    DynValue *argv;
    long long argc;
    cpy_async_loop *loop;
    cpy_async_future *wait_fut;
    cpy_async_future *task_fut;
    long long result_bits;
    struct cpy_async_fiber *next;
};

struct cpy_async_loop {
    cpy_async_fiber *ready_head;
    cpy_async_fiber *ready_tail;
    cpy_async_future *timers;   /* sorted ascending by deadline_ms */
    cpy_async_future *fds;      /* fd watchers */
    cpy_async_future *all_futures;
    cpy_async_fiber *all_fibers;
    cpy_async_fiber *free_fibers;
    cpy_async_fiber *current;
#if ASYNC_BACKEND_WIN
    void *main_fiber;          /* converted main-thread fiber */
    int main_fiber_owned;
#elif ASYNC_BACKEND_UCONTEXT
    ucontext_t main_ctx;
#else
    void *main_sp;
#endif
    int stopped;
    int nesting;
};

static cpy_async_fiber *g_executing;

void *__asyncio_loop; /* current/default loop, set by cpy_async_loop_new */

/* ============================ backend switches ============================ */

static void cpy_async_fiber_tramp(void);
#if ASYNC_BACKEND_WIN
static void cpy_async_fiber_to_main(cpy_async_loop *loop, cpy_async_fiber *f) {
    (void)f;
    SwitchToFiber(loop->main_fiber);
}
static void cpy_async_main_to_fiber(cpy_async_fiber *f) {
    SwitchToFiber(f->fiber);
}
#elif ASYNC_BACKEND_UCONTEXT
static void cpy_async_fiber_to_main(cpy_async_loop *loop, cpy_async_fiber *f) {
    if (swapcontext(&f->ctx, &loop->main_ctx) != 0) {
        perror("swapcontext");
        exit(1);
    }
}
static void cpy_async_main_to_fiber(cpy_async_fiber *f) {
    if (swapcontext(&f->loop->main_ctx, &f->ctx) != 0) {
        perror("swapcontext");
        exit(1);
    }
}
#else
/* The asm switcher. It is a naked function: it pushes the six call-saved
 * registers of the current context, records the resulting stack pointer,
 * loads the target context's saved pointer, restores that context's
 * call-saved registers and RETs into its suspension point. Both sides are
 * symmetric, so every resume restores the exact register state the resumed
 * fiber had when it suspended. A new fiber's stack is framed by
 * cpy_asm_stack_init so the first switch lands in cpy_async_fiber_tramp. */
#if defined(__x86_64__)
__attribute__((naked, noinline)) static void cpy_swctx(void **from_sp,
                                                       void *to_sp) {
    /* NOTE: single-% register names here. In a naked function clang does NOT
     * unescape "%%" on x86 (the asm string is emitted verbatim), so "%%rbp"
     * fails to compile; single "%rbp" is what reaches the assembler. */
    __asm__ volatile(
        "pushq %rbp\n\t"
        "pushq %rbx\n\t"
        "pushq %r12\n\t"
        "pushq %r13\n\t"
        "pushq %r14\n\t"
        "pushq %r15\n\t"
        "movq %rsp, (%rdi)\n\t"
        "movq %rsi, %rsp\n\t"
        "popq %r15\n\t"
        "popq %r14\n\t"
        "popq %r13\n\t"
        "popq %r12\n\t"
        "popq %rbx\n\t"
        "popq %rbp\n\t"
        "ret\n\t");
}
static void *cpy_asm_stack_init(char *stack, size_t size) {
    /* 7 words, low to high: r15 r14 r13 r12 rbx rbp rip. The loaded sp is
     * 16-aligned so the entry RSP (sp + 6*8 after the pops plus the ret) is
     * RSP%16==8, i.e. exactly as if the tramp had been called. */
    void **base =
        (void **)(((uintptr_t)stack + size + 8) & ~(uintptr_t)15);
    base[6] = (void *)cpy_async_fiber_tramp;
    base[5] = NULL;
    base[4] = NULL;
    base[3] = NULL;
    base[2] = NULL;
    base[1] = NULL;
    base[0] = NULL;
    return base;
}
#elif defined(__aarch64__)
__attribute__((naked, noinline)) static void cpy_swctx(void **from_sp,
                                                       void *to_sp) {
    __asm__ volatile(
        "stp x19, x20, [sp, #-16]!\n\t"
        "stp x21, x22, [sp, #-16]!\n\t"
        "stp x23, x24, [sp, #-16]!\n\t"
        "stp x25, x26, [sp, #-16]!\n\t"
        "stp x27, x28, [sp, #-16]!\n\t"
        "stp x29, x30, [sp, #-16]!\n\t"
        "mov x2, sp\n\t"
        "str x2, [x0]\n\t"
        "mov sp, x1\n\t"
        "ldp x29, x30, [sp], #16\n\t"
        "ldp x27, x28, [sp], #16\n\t"
        "ldp x25, x26, [sp], #16\n\t"
        "ldp x23, x24, [sp], #16\n\t"
        "ldp x21, x22, [sp], #16\n\t"
        "ldp x19, x20, [sp], #16\n\t"
        "ret\n\t");
}
static void *cpy_asm_stack_init(char *stack, size_t size) {
    /* 12 words, low to high: x29 x30 x27 x28 x25 x26 x23 x24 x21 x22 x19
     * x20, with x30 (the register `ret` jumps to) holding the tramp entry.
     * The loaded sp and the tramp entry SP are both 16-aligned. */
    void **base =
        (void **)(((uintptr_t)stack + size) & ~(uintptr_t)15) - 12;
    base[0] = NULL;
    base[1] = (void *)cpy_async_fiber_tramp;
    base[2] = NULL;
    base[3] = NULL;
    base[4] = NULL;
    base[5] = NULL;
    base[6] = NULL;
    base[7] = NULL;
    base[8] = NULL;
    base[9] = NULL;
    base[10] = NULL;
    base[11] = NULL;
    return base;
}
#endif

static void cpy_async_fiber_to_main(cpy_async_loop *loop, cpy_async_fiber *f) {
    cpy_swctx(&f->sp, loop->main_sp);
}
static void cpy_async_main_to_fiber(cpy_async_fiber *f) {
    cpy_swctx(&f->loop->main_sp, f->sp);
}
#endif

/* ============================ time and sleep ============================ */

static int64_t cpy_async_now_ms(void) {
#if ASYNC_BACKEND_WIN
    return (int64_t)GetTickCount64();
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
#endif
}

static void cpy_async_sleep_ms(int64_t ms) {
    if (ms <= 0) return;
#if ASYNC_BACKEND_WIN
    Sleep((DWORD)(ms > 50000 ? 50000 : ms));
#else
    struct timespec ts;
    ts.tv_sec = (time_t)(ms / 1000);
    ts.tv_nsec = (long)(ms % 1000) * 1000000;
    nanosleep(&ts, NULL);
#endif
}

static void cpy_async_fatal(const char *msg) {
    fputs("asyncio: ", stderr);
    fputs(msg, stderr);
    fputc('\n', stderr);
    exit(1);
}

/* ============================ fd event translation ============================ */

static short async_events_to_platform(short e) {
#if ASYNC_BACKEND_WIN
    short p = 0;
    if (e & ASYNC_EV_READ) p |= (short)POLLIN;
    if (e & ASYNC_EV_PRI) p |= (short)POLLPRI;
    if (e & ASYNC_EV_WRITE) p |= (short)POLLOUT;
    if (e & ASYNC_EV_ERR) p |= (short)POLLERR;
    if (e & ASYNC_EV_HUP) p |= (short)POLLHUP;
    return p;
#else
    return e;
#endif
}

static short async_platform_to_revents(short p) {
#if ASYNC_BACKEND_WIN
    short e = 0;
    if (p & POLLIN) e |= ASYNC_EV_READ;
    if (p & POLLPRI) e |= ASYNC_EV_PRI;
    if (p & POLLOUT) e |= ASYNC_EV_WRITE;
    if (p & POLLERR) e |= ASYNC_EV_ERR;
    if (p & POLLHUP) e |= ASYNC_EV_HUP;
    return e;
#else
    return p;
#endif
}

#if ASYNC_BACKEND_WIN
/* WSAStartup is needed before the first WSAPoll call. */
static int cpy_async_wsainit(void) {
    static int inited = 0;
    if (!inited) {
        WSADATA wsa;
        inited = WSAStartup(MAKEWORD(2, 2), &wsa) == 0;
    }
    return inited;
}
#endif

/* ============================ futures ============================ */

static cpy_async_future *cpy_async_future_new(cpy_async_loop *loop) {
    cpy_async_future *f = calloc(1, sizeof(*f));
    if (!f) return NULL;
    f->loop = loop;
    f->fd = -1;
    f->deadline_ms = -1;
    f->next = loop->all_futures;
    loop->all_futures = f;
    return f;
}

/* Complete a future: mark it done, requeue any awaiting fiber. */
static void cpy_async_future_finish(cpy_async_future *f, int state,
                                    int64_t result) {
    if (!f || f->state != ASYNC_STATE_PENDING) return;
    f->state = state;
    f->result = result;
    if (f->waiter) {
        cpy_async_fiber *w = f->waiter;
        f->waiter = NULL;
        if (w->state == ASYNC_FIBER_WAIT) {
            w->state = ASYNC_FIBER_READY;
            w->wait_fut = NULL;
            if (w->loop->ready_tail) w->loop->ready_tail->next = w;
            else w->loop->ready_head = w;
            w->loop->ready_tail = w;
        }
    }
}

/* ============================ fibers ============================ */

static cpy_async_fiber *cpy_async_fiber_alloc(cpy_async_loop *loop) {
    cpy_async_fiber *f = loop->free_fibers;
    if (f) {
        loop->free_fibers = f->next;
    } else {
        f = calloc(1, sizeof(*f));
        if (!f) return NULL;
        f->stack_size = ASYNC_STACK_SIZE;
#if !ASYNC_BACKEND_WIN
        f->stack = malloc(ASYNC_STACK_SIZE + 64);
        if (!f->stack) {
            free(f);
            return NULL;
        }
#endif
        f->next = loop->all_fibers;
        loop->all_fibers = f;
    }
    f->state = ASYNC_FIBER_NEW;
    f->entry = NULL;
    f->argv = NULL;
    f->argc = 0;
#if ASYNC_BACKEND_WIN
    f->fiber = NULL;
#elif ASYNC_BACKEND_UCONTEXT
    f->ctx_init = 0;
#else
    f->sp = NULL;
#endif
    return f;
}

static void cpy_async_fiber_release(cpy_async_loop *loop, cpy_async_fiber *f) {
    if (f->argv) {
        free(f->argv);
        f->argv = NULL;
    }
    if (f->task_fut) {
        f->task_fut->waiter = NULL; /* done anyway */
        f->task_fut = NULL;
    }
#if ASYNC_BACKEND_WIN
    if (f->fiber) {
        DeleteFiber(f->fiber);
        f->fiber = NULL;
    }
#endif
    f->state = ASYNC_FIBER_DONE;
    f->next = loop->free_fibers;
    loop->free_fibers = f;
}

#if ASYNC_BACKEND_WIN
/* CreateFiber back-ends the tramp and hands it the fiber as its parameter. */
static void WINAPI cpy_async_fiber_tramp(void *arg) {
    cpy_async_fiber *f = arg;
    g_executing = f;
    f->entry(f->argv);
    f->state = ASYNC_FIBER_DONE;
    cpy_async_future_finish(f->task_fut, ASYNC_STATE_DONE, f->result_bits);
    cpy_async_fiber_to_main(f->loop, f);
    cpy_async_fatal("fiber resumed after completion");
}
#else
static void cpy_async_fiber_tramp(void) {
    cpy_async_fiber *f = g_executing;
    f->entry(f->argv);
    f->state = ASYNC_FIBER_DONE;
    cpy_async_future_finish(f->task_fut, ASYNC_STATE_DONE, f->result_bits);
    cpy_async_fiber_to_main(f->loop, f);
    cpy_async_fatal("fiber resumed after completion");
}
#endif

/* Run one ready fiber to its next suspension point / completion. */
static void cpy_async_run_fiber(cpy_async_loop *loop, cpy_async_fiber *f) {
    loop->current = f;
    g_executing = f;
    f->state = ASYNC_FIBER_RUNNING;
#if ASYNC_BACKEND_WIN
    if (!f->fiber) {
        f->fiber = CreateFiber(f->stack_size,
                               (LPFIBER_START_ROUTINE)cpy_async_fiber_tramp, f);
        if (!f->fiber) cpy_async_fatal("CreateFiber failed");
    }
#elif ASYNC_BACKEND_UCONTEXT
    if (!f->ctx_init) {
        if (getcontext(&f->ctx) != 0) {
            perror("getcontext");
            exit(1);
        }
        f->ctx.uc_stack.ss_sp = f->stack;
        f->ctx.uc_stack.ss_size = f->stack_size;
        f->ctx.uc_link = NULL;
        makecontext(&f->ctx, cpy_async_fiber_tramp, 0);
        f->ctx_init = 1;
    }
#else
    if (!f->sp) f->sp = cpy_asm_stack_init(f->stack, f->stack_size);
#endif
    cpy_async_main_to_fiber(f);
    loop->current = NULL;
    g_executing = NULL;
    if (f->state == ASYNC_FIBER_DONE) cpy_async_fiber_release(loop, f);
}

static void cpy_async_queue(cpy_async_loop *loop, cpy_async_fiber *f) {
    f->state = ASYNC_FIBER_READY;
    f->next = NULL;
    if (loop->ready_tail) loop->ready_tail->next = f;
    else loop->ready_head = f;
    loop->ready_tail = f;
}

static cpy_async_fiber *cpy_async_pop(cpy_async_loop *loop) {
    cpy_async_fiber *f = loop->ready_head;
    if (!f) return NULL;
    loop->ready_head = f->next;
    if (!loop->ready_head) loop->ready_tail = NULL;
    f->next = NULL;
    return f;
}

/* Insert a timer future, keeping the list sorted ascending by deadline. */
static void cpy_async_timer_insert(cpy_async_loop *loop, cpy_async_future *f) {
    cpy_async_future **pp = &loop->timers;
    while (*pp && (*pp)->deadline_ms <= f->deadline_ms) pp = &(*pp)->next;
    f->next = *pp;
    *pp = f;
}

/* Complete every timer future whose deadline has passed. Returns 1 if any. */
static int cpy_async_advance_timers(cpy_async_loop *loop, int64_t now) {
    int done = 0;
    while (loop->timers && loop->timers->deadline_ms <= now) {
        cpy_async_future *f = loop->timers;
        loop->timers = f->next;
        cpy_async_future_finish(f, ASYNC_STATE_DONE, 0);
        done = 1;
    }
    return done;
}

/* Earliest pending deadline across timers and fds, or -1 if none. */
static int64_t cpy_async_next_deadline(cpy_async_loop *loop, int64_t now) {
    int64_t next = -1;
    if (loop->timers) next = loop->timers->deadline_ms;
    for (cpy_async_future *f = loop->fds; f; f = f->next) {
        if (f->state != ASYNC_STATE_PENDING || f->deadline_ms < 0) continue;
        if (next < 0 || f->deadline_ms < next) next = f->deadline_ms;
    }
    return next;
}

static int cpy_async_has_waitable(cpy_async_loop *loop) {
    return loop->fds != NULL || loop->timers != NULL;
}

/* Poll fd watchers; complete ready/timeout futures. Returns 1 on progress. */
static int cpy_async_poll_fds(cpy_async_loop *loop, int64_t now, int timeout) {
#if ASYNC_BACKEND_WIN
    if (!cpy_async_wsainit()) return 0;
#endif
    size_t n = 0;
    for (cpy_async_future *f = loop->fds; f; f = f->next)
        if (f->state == ASYNC_STATE_PENDING && f->fd >= 0) n++;
    if (!n) return 0;
#if ASYNC_BACKEND_WIN
    WSAPOLLFD *pfds = calloc(n, sizeof(*pfds));
#else
    struct pollfd *pfds = calloc(n, sizeof(*pfds));
#endif
    cpy_async_future **map = calloc(n, sizeof(*map));
    if (!pfds || !map) {
        free(pfds);
        free(map);
        return 0;
    }
    size_t i = 0;
    for (cpy_async_future *f = loop->fds; f; f = f->next) {
        if (f->state == ASYNC_STATE_PENDING && f->fd >= 0) {
#if ASYNC_BACKEND_WIN
            pfds[i].fd = (SOCKET)(intptr_t)f->fd;
            pfds[i].events = async_events_to_platform(f->events);
            pfds[i].revents = 0;
#else
            pfds[i].fd = f->fd;
            pfds[i].events = f->events;
#endif
            map[i++] = f;
        }
    }
#if ASYNC_BACKEND_WIN
    int r = WSAPoll(pfds, (ULONG)i, timeout);
#else
    int r = poll(pfds, (nfds_t)i, timeout);
#endif
    int progress = 0;
    now = cpy_async_now_ms();
    if (r > 0) {
        for (size_t j = 0; j < i; j++) {
            cpy_async_future *f = map[j];
#if ASYNC_BACKEND_WIN
            short rev = async_platform_to_revents(pfds[j].revents);
#else
            short rev = pfds[j].revents;
#endif
            if ((rev & f->events) != 0) {
                cpy_async_future_finish(f, ASYNC_STATE_DONE, rev);
                progress = 1;
            }
        }
    }
    for (size_t j = 0; j < i; j++) {
        cpy_async_future *f = map[j];
        if (f->state == ASYNC_STATE_PENDING && f->deadline_ms >= 0 &&
            now >= f->deadline_ms) {
            cpy_async_future_finish(f, ASYNC_STATE_DONE, 0);
            progress = 1;
        }
    }
    free(pfds);
    free(map);
    return progress;
}

/* ============================ public API ============================ */

void *cpy_async_loop_new(void) {
    cpy_async_loop *loop = calloc(1, sizeof(*loop));
    if (!loop) return NULL;
    __asyncio_loop = loop;
    return loop;
}

void *cpy_async_current_loop(void) { return __asyncio_loop; }

void cpy_async_loop_stop(void *raw) {
    if (!raw) return;
    ((cpy_async_loop *)raw)->stopped = 1;
}

void cpy_async_loop_free(void *raw) {
    if (!raw) return;
    cpy_async_loop *loop = raw;
    cpy_async_future *f = loop->all_futures;
    while (f) {
        cpy_async_future *next = f->next;
        free(f);
        f = next;
    }
    cpy_async_fiber *fb = loop->all_fibers;
    while (fb) {
        cpy_async_fiber *next = fb->next;
#if ASYNC_BACKEND_WIN
        if (fb->fiber) DeleteFiber(fb->fiber);
#endif
        free(fb->stack);
        free(fb);
        fb = next;
    }
#if ASYNC_BACKEND_WIN
    if (loop->main_fiber_owned && loop->main_fiber) {
        ConvertFiberToThread();
        loop->main_fiber = NULL;
        loop->main_fiber_owned = 0;
    }
#endif
    free(loop);
    if (__asyncio_loop == raw) __asyncio_loop = NULL;
}

void *cpy_async_sleep(void *raw, int64_t delay_ms) {
    cpy_async_loop *loop = raw;
    if (!loop) return NULL;
    if (delay_ms < 0) delay_ms = 0;
    cpy_async_future *f = cpy_async_future_new(loop);
    if (!f) return NULL;
    f->deadline_ms = cpy_async_now_ms() + delay_ms;
    cpy_async_timer_insert(loop, f);
    return f;
}

void *cpy_async_fd_wait(void *raw, int fd, int events, int64_t timeout_ms) {
    cpy_async_loop *loop = raw;
    if (!loop || fd < 0) return NULL;
    cpy_async_future *f = cpy_async_future_new(loop);
    if (!f) return NULL;
    f->fd = fd;
    f->events = (short)events;
    f->deadline_ms = timeout_ms < 0 ? -1 : cpy_async_now_ms() + timeout_ms;
    f->next = loop->fds;
    loop->fds = f;
    return f;
}

int cpy_async_future_ready(void *raw) {
    if (!raw) return 0;
    return ((cpy_async_future *)raw)->state != ASYNC_STATE_PENDING;
}

int cpy_async_future_cancel(void *raw) {
    if (!raw) return 0;
    cpy_async_future *f = raw;
    if (f->state != ASYNC_STATE_PENDING) return 0;
    cpy_async_future_finish(f, ASYNC_STATE_CANCELLED, 0);
    return 1;
}

int64_t cpy_async_future_result(void *raw) {
    if (!raw) return 0;
    return ((cpy_async_future *)raw)->result;
}

int cpy_async_future_state(void *raw) {
    if (!raw) return ASYNC_STATE_FAILED;
    return ((cpy_async_future *)raw)->state;
}

int cpy_async_loop_run(void *raw, void *until_raw) {
    cpy_async_loop *loop = raw;
    cpy_async_future *until = until_raw;
    if (!loop) return ASYNC_STATE_FAILED;
    if (loop->nesting != 0) cpy_async_fatal("nested run() is not supported");
#if ASYNC_BACKEND_WIN
    if (!loop->main_fiber) {
        loop->main_fiber = ConvertThreadToFiber(NULL);
        if (!loop->main_fiber) cpy_async_fatal("ConvertThreadToFiber failed");
        loop->main_fiber_owned = 1;
    }
#endif
    loop->nesting = 1;
    for (;;) {
        if (loop->stopped) break;
        if (until && until->state != ASYNC_STATE_PENDING) break;
        cpy_async_fiber *f = cpy_async_pop(loop);
        if (f) {
            cpy_async_run_fiber(loop, f);
            continue;
        }
        int64_t now = cpy_async_now_ms();
        if (cpy_async_advance_timers(loop, now)) continue;
        if (loop->fds) {
            int64_t next = cpy_async_next_deadline(loop, now);
            int timeout = -1;
            if (next >= 0) {
                int64_t left = next - now;
                timeout = left > 2147483647LL ? 2147483647 : (int)(left < 0 ? 0 : left);
            }
            cpy_async_poll_fds(loop, now, timeout);
            if (cpy_async_advance_timers(loop, cpy_async_now_ms())) continue;
            if (until && until->state != ASYNC_STATE_PENDING) break;
            now = cpy_async_now_ms();
            if (cpy_async_advance_timers(loop, now)) continue;
            continue;
        }
        if (loop->timers) {
            int64_t next = loop->timers->deadline_ms;
            int64_t left = next - now;
            cpy_async_sleep_ms(left);
            continue;
        }
        break; /* nothing runnable, nothing waitable */
    }
    loop->nesting = 0;
    return until ? until->state : ASYNC_STATE_DONE;
}

/* ============================ async/await primitives ============================ */

/* Box a task arg. argv points to `argc` DynValue slots already allocated. */
void cpy_async_box_arg(void *argv_v, long long idx, int kind, long long bits) {
    DynValue *argv = argv_v;
    argv[idx].kind = kind;
    argv[idx].data = (uint64_t)bits;
}

/* Spawn a task: schedules the fiber to run `entry(argv)` on completion of the
 * returned task future. argv is deep-copied so the caller's stack can go. */
void *cpy_async_task_spawn(void *loop_v, void *entry, void *argv_v,
                           long long argc) {
    cpy_async_loop *loop = loop_v;
    if (!loop) loop = __asyncio_loop;
    if (!loop) cpy_async_fatal("task_spawn: no event loop (call loop_new first)");
    cpy_async_fiber *f = cpy_async_fiber_alloc(loop);
    if (!f) cpy_async_fatal("task_spawn: out of memory");
    f->loop = loop;
    f->entry = (void (*)(void *))entry;
    f->argc = argc;
    if (argc > 0) {
        f->argv = malloc((size_t)argc * sizeof(DynValue));
        if (!f->argv) cpy_async_fatal("task_spawn: out of memory");
        memcpy(f->argv, argv_v, (size_t)argc * sizeof(DynValue));
    }
    f->task_fut = cpy_async_future_new(loop);
    cpy_async_queue(loop, f);
    return f->task_fut;
}

/* Store the current task's result (called by the rewritten `return expr`). */
void cpy_async_task_set_result(long long bits) {
    if (!g_executing) cpy_async_fatal("task_set_result outside a task body");
    g_executing->result_bits = bits;
}

/* The heart of `await`: suspend the current fiber until `fut` completes. */
long long cpy_async_await(void *fut_v) {
    cpy_async_future *fut = fut_v;
    if (!fut) cpy_async_fatal("await NULL future");
    cpy_async_loop *loop = fut->loop;
    if (!loop) loop = __asyncio_loop;
    cpy_async_fiber *f = loop ? loop->current : NULL;
    if (!f) cpy_async_fatal("await outside of a task fiber");
    if (fut->state != ASYNC_STATE_PENDING) return fut->result;
    if (fut->waiter) {
        cpy_async_fatal("future already awaited by another task");
    }
    fut->waiter = f;
    f->wait_fut = fut;
    f->state = ASYNC_FIBER_WAIT;
    cpy_async_fiber_to_main(loop, f);
    return fut->result;
}

/* ============================ arg unboxing ============================ */

long long cpy_async_arg_i32(void *argv_v, long long idx) {
    DynValue *argv = argv_v;
    DynValue *d = &argv[idx];
    switch (d->kind) {
    case 1: /* DYN_INT */
        return (long long)(int32_t)(int64_t)d->data;
    case 2: /* DYN_INT64 */
    case 3: /* DYN_UINT64 */
        return (long long)d->data;
    default:
        return 0;
    }
}

long long cpy_async_arg_i64(void *argv_v, long long idx) {
    DynValue *argv = argv_v;
    return (long long)argv[idx].data;
}

double cpy_async_arg_f64(void *argv_v, long long idx) {
    DynValue *argv = argv_v;
    double v;
    memcpy(&v, &argv[idx].data, 8);
    return v;
}

void *cpy_async_arg_ptr(void *argv_v, long long idx) {
    DynValue *argv = argv_v;
    return (void *)(uintptr_t)argv[idx].data;
}
"""


def get_hooks():
    return [AsyncRuntimeHook()]