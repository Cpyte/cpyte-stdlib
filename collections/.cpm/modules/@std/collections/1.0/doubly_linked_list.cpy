import stdlib

# Doubly linked list. Nodes hold a void* value plus prev/next pointers.
# The language cannot do deep pointer-field chains, so pointer fields are
# always extracted into a local DLNode* first.
# Structs are passed by value: field-mutating ops return the updated list,
# so callers write `list = dll_append(list, v)`.
struct DLNode:
    void* value
    DLNode* prev
    DLNode* next

struct DoublyLinkedList:
    DLNode* head
    DLNode* tail
    size_t length

public def create_doublylinkedlist() -> DoublyLinkedList:
    DoublyLinkedList list
    list.head = 0
    list.tail = 0
    list.length = (size_t)0
    return list

# Prepend at the head (O(1)). Returns the updated list.
public def dll_prepend(list DoublyLinkedList, value void*) -> DoublyLinkedList:
    DLNode* node = new DLNode
    node.value = value
    node.prev = 0
    node.next = list.head
    if list.head != 0:
        DLNode* h = list.head
        h.prev = node
    else:
        list.tail = node
    list.head = node
    list.length += (size_t)1
    return list

# Append at the tail (O(1)). Returns the updated list.
public def dll_append(list DoublyLinkedList, value void*) -> DoublyLinkedList:
    DLNode* node = new DLNode
    node.value = value
    node.prev = list.tail
    node.next = 0
    if list.tail != 0:
        DLNode* t = list.tail
        t.next = node
    else:
        list.head = node
    list.tail = node
    list.length += (size_t)1
    return list

# Pop the head and return the updated list. Peek value first with dll_front.
public def dll_pop_front(list DoublyLinkedList) -> DoublyLinkedList:
    if list.head == 0:
        return list
    DLNode* h = list.head
    DLNode* nh = h.next
    list.head = nh
    if nh != 0:
        nh.prev = 0
    else:
        list.tail = 0
    list.length -= (size_t)1
    return list

# Pop the tail and return the updated list. Peek value first with dll_back.
public def dll_pop_back(list DoublyLinkedList) -> DoublyLinkedList:
    if list.tail == 0:
        return list
    DLNode* t = list.tail
    DLNode* pt = t.prev
    list.tail = pt
    if pt != 0:
        pt.next = 0
    else:
        list.head = 0
    list.length -= (size_t)1
    return list

public def dll_front(list DoublyLinkedList) -> void*:
    if list.head == 0:
        return 0
    DLNode* h = list.head
    return h.value

public def dll_back(list DoublyLinkedList) -> void*:
    if list.tail == 0:
        return 0
    DLNode* t = list.tail
    return t.value

# Remove the first node holding `value`, returning the updated list.
public def dll_remove(list DoublyLinkedList, value void*) -> DoublyLinkedList:
    DLNode* cur = list.head
    while cur != 0:
        if cur.value == value:
            DLNode* p = cur.prev
            DLNode* n = cur.next
            if p != 0:
                p.next = n
            else:
                list.head = n
            if n != 0:
                n.prev = p
            else:
                list.tail = p
            list.length -= (size_t)1
            return list
        cur = cur.next
    return list

public def dll_contains(list DoublyLinkedList, value void*) -> bool:
    int found = 0
    DLNode* cur = list.head
    while cur != 0:
        if cur.value == value:
            found = 1
        cur = cur.next
    return found == 1

public def dll_at(list DoublyLinkedList, i size_t) -> void*:
    if i >= list.length:
        return 0
    DLNode* cur = list.head
    size_t k = (size_t)0
    while cur != 0:
        if k == i:
            return cur.value
        cur = cur.next
        k = k + (size_t)1
    return 0

public def dll_size(list DoublyLinkedList) -> size_t:
    return list.length

public def dll_is_empty(list DoublyLinkedList) -> bool:
    return list.head == 0
