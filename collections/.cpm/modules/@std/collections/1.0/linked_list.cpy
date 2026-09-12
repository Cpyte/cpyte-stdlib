import stdlib

# Singly linked list. Nodes hold a void* value and a next pointer.
# The language cannot do deep pointer-field chains (e.g. list.head.next), so
# pointer fields are always extracted into a local ListNode* first.
# Structs are passed by value: field-mutating ops return the updated list,
# so callers write `list = ll_append(list, v)`.
struct ListNode:
    void* value
    ListNode* next

struct LinkedList:
    ListNode* head
    ListNode* tail
    size_t length

public def create_linkedlist() -> LinkedList:
    LinkedList list
    list.head = 0
    list.tail = 0
    list.length = (size_t)0
    return list

# Prepend at the head (O(1)). Returns the updated list.
public def ll_prepend(list LinkedList, value void*) -> LinkedList:
    ListNode* node = new ListNode
    node.value = value
    node.next = list.head
    if list.tail == 0:
        list.tail = node
    list.head = node
    list.length += (size_t)1
    return list

# Append at the tail (O(1) with tail pointer). Returns the updated list.
public def ll_append(list LinkedList, value void*) -> LinkedList:
    ListNode* node = new ListNode
    node.value = value
    node.next = 0
    if list.tail == 0:
        list.head = node
        list.tail = node
    else:
        ListNode* t = list.tail
        t.next = node
        list.tail = node
    list.length += (size_t)1
    return list

# Pop the head and return the updated list. Peek value first with ll_front.
public def ll_pop_front(list LinkedList) -> LinkedList:
    if list.head == 0:
        return list
    ListNode* h = list.head
    list.head = h.next
    if list.head == 0:
        list.tail = 0
    list.length -= (size_t)1
    return list

# Peek at the head value without removing it.
public def ll_front(list LinkedList) -> void*:
    if list.head == 0:
        return 0
    ListNode* h = list.head
    return h.value

# Pop the tail and return the updated list. Peek value first with ll_back.
public def ll_pop_back(list LinkedList) -> LinkedList:
    if list.tail == 0:
        return list
    if list.head == list.tail:
        list.head = 0
        list.tail = 0
        list.length = (size_t)0
        return list
    ListNode* cur = list.head
    while cur.next != 0 and cur.next != list.tail:
        cur = cur.next
    cur.next = 0
    list.tail = cur
    list.length -= (size_t)1
    return list

public def ll_back(list LinkedList) -> void*:
    if list.tail == 0:
        return 0
    ListNode* t = list.tail
    return t.value

# Remove the first node whose value pointer equals `value`, returning the
# updated list. Use ll_contains to test presence beforehand.
public def ll_remove(list LinkedList, value void*) -> LinkedList:
    if list.head == 0:
        return list
    ListNode* h = list.head
    if h.value == value:
        return ll_pop_front(list)
    ListNode* cur = list.head
    while cur.next != 0:
        ListNode* n = cur.next
        if n.value == value:
            cur.next = n.next
            if n == list.tail:
                list.tail = cur
            list.length -= (size_t)1
            return list
        cur = n
    return list

public def ll_contains(list LinkedList, value void*) -> bool:
    int found = 0
    ListNode* cur = list.head
    while cur != 0:
        if cur.value == value:
            found = 1
        cur = cur.next
    return found == 1

# Fetch the element at index (0-based), or NULL if out of bounds.
public def ll_at(list LinkedList, i size_t) -> void*:
    if i >= list.length:
        return 0
    ListNode* cur = list.head
    size_t k = (size_t)0
    while cur != 0:
        if k == i:
            return cur.value
        cur = cur.next
        k = k + (size_t)1
    return 0

public def ll_size(list LinkedList) -> size_t:
    return list.length

public def ll_is_empty(list LinkedList) -> bool:
    return list.head == 0
