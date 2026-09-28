"""
Mentra RAG Independent CLI Test Harness.

Allows testing document ingestion, chunk inspection, embedding status,
semantic similarity search, metadata inspection, and index clearing
completely independent of the UI or conversational layer.
"""

import argparse
import json
import sys
from pathlib import Path

from app.services.rag.rag_engine import rag_engine
from app.services.rag.exceptions import RAGError


def cmd_ingest(args):
    file_path = Path(args.path)
    if not file_path.exists():
        print(f"ERROR: File not found at '{file_path}'", file=sys.stderr)
        sys.exit(1)

    print(f"[*] Ingesting file: {file_path}")
    try:
        result = rag_engine.ingest_file(
            file_path=file_path,
            title=args.title,
            doc_id=args.id,
        )
        print("\n=== INGESTION RESULT ===")
        print(f"Status:        {result.status}")
        print(f"Is Duplicate:  {result.is_duplicate}")
        print(f"Document ID:   {result.doc_id}")
        print(f"Title:         {result.title}")
        print(f"Filename:      {result.filename}")
        print(f"File Type:     {result.file_type}")
        print(f"File SHA-256:  {result.file_hash}")
        print(f"Char Count:    {result.char_count}")
        print(f"Chunk Count:   {result.chunk_count}")
        print("========================")
    except RAGError as e:
        print(f"INGESTION FAILED [{e.code}]: {e.message}", file=sys.stderr)
        sys.exit(1)


def cmd_list(args):
    docs = rag_engine.list_documents()
    print(f"\n=== INDEXED DOCUMENTS ({len(docs)} total) ===")
    if not docs:
        print("No documents currently indexed.")
        return

    for i, d in enumerate(docs, 1):
        print(f"\n[{i}] {d['title']}")
        print(f"    Doc ID:      {d['doc_id']}")
        print(f"    Filename:    {d['filename']} ({d['file_type']})")
        print(f"    Hash:        {d['file_hash'][:16]}...")
        print(f"    Chunks:      {d['chunk_count']}")
        print(f"    Characters:  {d['char_count']}")
        print(f"    Updated:     {d['updated_at']}")
    print("========================================")


def cmd_query(args):
    query_text = args.query.strip()
    print(f"[*] Query: '{query_text}'")
    print(f"[*] Parameters: top_k={args.top_k}, threshold={args.threshold}")

    try:
        response = rag_engine.retrieve_context(
            query=query_text,
            top_k=args.top_k,
            threshold=args.threshold,
        )

        print("\n=== RETRIEVAL RESULTS ===")
        print(f"Status:         {response.status}")
        print(f"Results Count:  {response.results_count}")

        if response.status == "NO_RELEVANT_CONTEXT":
            print("\n[-] NO_RELEVANT_CONTEXT (No chunks met relevance threshold)")
            print("=========================")
            return

        print("\n--- RANKED CHUNKS ---")
        for i, chunk in enumerate(response.results, 1):
            score = chunk["similarity_score"]
            print(f"\n[Rank {i}] Similarity Score: {score:.4f}")
            print(f"  Chunk ID:   {chunk['chunk_id']}")
            print(f"  Document:   {chunk['doc_title']} ({chunk['filename']})")
            if chunk.get("page_number") is not None:
                print(f"  Page:       {chunk['page_number']}")
            if chunk.get("section_heading"):
                print(f"  Section:    {chunk['section_heading']}")
            print(f"  Text Excerpt:")
            text_lines = chunk["text"].split("\n")
            preview = text_lines[0][:100] + ("..." if len(text_lines[0]) > 100 or len(text_lines) > 1 else "")
            print(f"    \"{preview}\"")

        print("\n--- FORMATTED GROUNDING CONTEXT ---")
        print(response.formatted_context)
        print("===================================")
    except RAGError as e:
        print(f"QUERY FAILED [{e.code}]: {e.message}", file=sys.stderr)
        sys.exit(1)


def cmd_stats(args):
    stats = rag_engine.get_stats()
    print("\n=== RAG ENGINE STATUS & STATISTICS ===")
    print(f"Documents:           {stats['document_count']}")
    print(f"Total Chunks:        {stats['chunk_count']}")
    print(f"Embedding Model:     {stats['embedding_model']}")
    print(f"Embedding Dimension: {stats['embedding_dimension']}")
    print(f"Runtime:             {stats['runtime']}")
    print(f"Vector Store Type:   {stats['vector_store_type']}")
    print(f"Vector Store Path:   {stats['vector_store_path']}")
    print(f"Storage Size:        {stats['storage_size_bytes']} bytes ({stats['storage_size_bytes'] / 1024:.2f} KB)")
    print("======================================")


def cmd_delete(args):
    doc_id = args.id
    success = rag_engine.remove_document(doc_id)
    if success:
        print(f"[+] Document '{doc_id}' and its chunks removed successfully.")
    else:
        print(f"[-] Document '{doc_id}' not found.")


def cmd_clear(args):
    if not args.yes:
        confirm = input("Are you sure you want to clear the entire RAG index? [y/N]: ")
        if confirm.lower() != "y":
            print("Aborted.")
            return
    rag_engine.clear_index()
    print("[+] Entire RAG index cleared.")


def main():
    parser = argparse.ArgumentParser(description="Mentra RAG Independent Test Harness")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Ingest
    ingest_p = subparsers.add_parser("ingest", help="Ingest a document file (.txt, .md, .pdf)")
    ingest_p.add_argument("path", help="Path to file")
    ingest_p.add_argument("--title", help="Optional document title override")
    ingest_p.add_argument("--id", help="Optional document ID override")
    ingest_p.set_defaults(func=cmd_ingest)

    # List
    list_p = subparsers.add_parser("list", help="List all indexed documents")
    list_p.set_defaults(func=cmd_list)

    # Query
    query_p = subparsers.add_parser("query", help="Query the RAG index with semantic search")
    query_p.add_argument("query", help="Search query string")
    query_p.add_argument("--top-k", type=int, default=4, help="Maximum chunks to return (default: 4)")
    query_p.add_argument("--threshold", type=float, default=0.35, help="Relevance score threshold (default: 0.35)")
    query_p.set_defaults(func=cmd_query)

    # Stats
    stats_p = subparsers.add_parser("stats", help="Show RAG engine statistics and status")
    stats_p.set_defaults(func=cmd_stats)

    # Delete
    del_p = subparsers.add_parser("delete", help="Delete a document by doc_id")
    del_p.add_argument("id", help="Document ID to delete")
    del_p.set_defaults(func=cmd_delete)

    # Clear
    clear_p = subparsers.add_parser("clear", help="Clear all documents and chunks")
    clear_p.add_argument("-y", "--yes", action="store_true", help="Skip confirmation")
    clear_p.set_defaults(func=cmd_clear)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
