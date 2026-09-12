import stdlib

# Stack (LIFO). Backed by a growable contiguous buffer; stores void*.
# Structs are passed by value: field-mutating ops return the updated Stack.
struct Stack:
    void** data
    size_t capacity
    size_t length

public def create_stack(cap size_t) -> Stack:
    assert cap >= (size_t)1, "Value Error: You cannot create a stack of capacity below 1"
    Stack st
    st.capacity = cap
    st.data = malloc(cap * (size_t)sizeof(void*))
    st.length = (size_t)0
    return st

public def _stack_grow(st Stack) -> Stack:
    size_t new_size = st.capacity * (size_t)2
    assert new_size > st.capacity, "Value Error: stack capacity overflow"
    Stack ns
    ns.capacity = new_size
    ns.data = malloc(new_size * (size_t)sizeof(void*))
    ns.length = st.length
    for i in range((int)st.length):
        ns.data[i] = st.data[i]
    return ns

public def stack_push(st Stack, value void*) -> Stack:
    if st.length >= st.capacity:
        Stack grown = _stack_grow(st)
        return stack_push(grown, value)
    st.data[st.length] = value
    st.length += (size_t)1
    return st

# Pop the top element and return the updated Stack.
# Peek before popping if you need the value.
public def stack_pop(st Stack) -> Stack:
    if st.length == (size_t)0:
        return st
    st.length -= (size_t)1
    return st

# Peek at the top element without removing it.
public def stack_peek(st Stack) -> void*:
    if st.length == (size_t)0:
        return 0
    return st.data[st.length - (size_t)1]

public def stack_size(st Stack) -> size_t:
    return st.length

public def stack_is_empty(st Stack) -> bool:
    return st.length == (size_t)0
