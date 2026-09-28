# Mentra RAG Test Notes

## Array Data Structure
Arrays are contiguous collections of elements stored in adjacent memory locations. Because elements are placed sequentially, arrays provide O(1) constant-time direct access via index arithmetic. However, inserting or deleting elements from the middle of an array requires shifting remaining elements, leading to O(n) worst-case time complexity. Dynamic arrays resize automatically by doubling capacity when full.

## Stack Data Structure
A stack follows LIFO (Last In First Out) principle, where the last element inserted is the first element removed. Primary operations include push to add an element to the top, pop to remove the top element, and peek to inspect without removing. All these operations run in O(1) constant time. Classic applications of stacks include function call recursion frames, undo operations in editors, and syntax parsing for balanced parentheses.

## Queue Data Structure
A queue follows FIFO (First In First Out) principle, where the first element inserted is the first one processed. Primary operations are enqueue to insert at the rear and dequeue to extract from the front, both operating in O(1) time. Common applications include CPU task scheduling, print job buffering, and breadth-first search graph traversals. Priority queues order elements by urgency rather than arrival time.

## Database Normalization
Database normalization reduces data redundancy and improves data integrity by organizing fields and table relationships according to formal rules. First Normal Form (1NF) eliminates repeating groups and enforces atomic values. Second Normal Form (2NF) ensures all non-key attributes are fully functionally dependent on the primary key. Third Normal Form (3NF) removes transitive dependencies. Normalization prevents insertion, update, and deletion anomalies.
