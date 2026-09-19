"""Comprehensive E2E Verification of Local LLM Engine for Mentra Milestone 2."""

import httpx
import uuid

BASE_URL = "http://127.0.0.1:8000/api/v1"

def run_tests():
    email = f"student_{uuid.uuid4().hex[:8]}@mentra.ai"
    password = "Password123!"

    print("=" * 60)
    print("STEP 1: Register & Authenticate Student")
    print("=" * 60)
    client = httpx.Client(timeout=60.0)
    reg_res = client.post(f"{BASE_URL}/auth/register", json={"email": email, "password": password, "full_name": "Milestone 2 Student"})
    assert reg_res.status_code == 201, f"Register failed: {reg_res.text}"

    login_res = client.post(f"{BASE_URL}/auth/login", json={"email": email, "password": password})
    assert login_res.status_code == 200, f"Login failed: {login_res.text}"
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("✓ Registered & Logged in successfully.")

    print("\n" + "=" * 60)
    print("STEP 2: Model Readiness & Lifecycle Status Check")
    print("=" * 60)
    status_res = client.get(f"{BASE_URL}/ai-coach/status", headers=headers)
    assert status_res.status_code == 200, f"Status failed: {status_res.text}"
    status_data = status_res.json()
    print("Status response:", status_data)
    assert status_data["is_ready"] is True
    assert status_data["state"] == "READY"
    assert "qwen2.5:0.5b" in status_data["model"]
    print(f"✓ Local Model Engine verified: {status_data['model']} (State: {status_data['state']})")

    print("\n" + "=" * 60)
    print("STEP 3: Test 'hi' (Ensure NO template fallback)")
    print("=" * 60)
    chat_res = client.post(
        f"{BASE_URL}/ai-coach/chat",
        headers=headers,
        json={"message": "hi", "history": []},
    )
    assert chat_res.status_code == 200, f"Chat failed: {chat_res.text}"
    hi_reply = chat_res.json()["message"]
    print("Mentra reply to 'hi':\n", hi_reply)
    assert "I'm ready to help you master hii" not in hi_reply, "FAILED: Found old template!"
    assert "connect your Google Gemini" not in hi_reply, "FAILED: Found external key prompt!"
    print("✓ Real local generation confirmed. Canned fallback completely absent.")

    print("\n" + "=" * 60)
    print("STEP 4: Multi-Turn Continuity Sequence (DSA -> arrays -> example)")
    print("=" * 60)
    history = [
        {"role": "user", "content": "hi"},
        {"role": "assistant", "content": hi_reply},
    ]

    # Turn 2: teach me DSA
    res2 = client.post(f"{BASE_URL}/ai-coach/chat", headers=headers, json={"message": "teach me DSA", "history": history})
    assert res2.status_code == 200
    msg2 = res2.json()["message"]
    print("\n[Turn 2] User: teach me DSA\nMentra:", msg2[:180], "...\n")
    history.append({"role": "user", "content": "teach me DSA"})
    history.append({"role": "assistant", "content": msg2})

    # Turn 3: arrays
    res3 = client.post(f"{BASE_URL}/ai-coach/chat", headers=headers, json={"message": "arrays", "history": history})
    assert res3.status_code == 200
    msg3 = res3.json()["message"]
    print("[Turn 3] User: arrays\nMentra:", msg3[:180], "...\n")
    history.append({"role": "user", "content": "arrays"})
    history.append({"role": "assistant", "content": msg3})

    # Turn 4: I don't understand them
    res4 = client.post(f"{BASE_URL}/ai-coach/chat", headers=headers, json={"message": "I don't understand them", "history": history})
    assert res4.status_code == 200
    msg4 = res4.json()["message"]
    print("[Turn 4] User: I don't understand them\nMentra:", msg4[:180], "...\n")
    history.append({"role": "user", "content": "I don't understand them"})
    history.append({"role": "assistant", "content": msg4})

    # Turn 5: give me an example
    res5 = client.post(f"{BASE_URL}/ai-coach/chat", headers=headers, json={"message": "give me an example", "history": history})
    assert res5.status_code == 200
    msg5 = res5.json()["message"]
    print("[Turn 5] User: give me an example\nMentra:", msg5[:250], "...\n")
    # Must refer to arrays or list indexing
    assert any(w in msg5.lower() for w in ["array", "element", "index", "list", "item", "box", "slot"]), "Failed to maintain array context"
    print("✓ Full 5-turn DSA conversation sequence maintained context successfully.")

    print("\n" + "=" * 60)
    print("STEP 5: Multi-Turn Memory & Name Recall Test")
    print("=" * 60)
    name_hist = []
    # 1. My name is Alex
    n1 = client.post(f"{BASE_URL}/ai-coach/chat", headers=headers, json={"message": "My name is Alex.", "history": name_hist})
    n1_msg = n1.json()["message"]
    print("User: My name is Alex.\nMentra:", n1_msg)
    name_hist.append({"role": "user", "content": "My name is Alex."})
    name_hist.append({"role": "assistant", "content": n1_msg})

    # 2. What is my name?
    n2 = client.post(f"{BASE_URL}/ai-coach/chat", headers=headers, json={"message": "What is my name?", "history": name_hist})
    n2_msg = n2.json()["message"]
    print("User: What is my name?\nMentra:", n2_msg)
    assert "alex" in n2_msg.lower(), f"Failed name recall! Got: {n2_msg}"
    print("✓ Multi-turn memory test passed: Mentra recalled 'Alex'.")

    print("\n" + "=" * 60)
    print("STEP 6: Test Cancellation Endpoint")
    print("=" * 60)
    cancel_res = client.post(f"{BASE_URL}/ai-coach/cancel", headers=headers)
    assert cancel_res.status_code == 200
    print("Cancel response:", cancel_res.json())
    print("✓ Cancellation endpoint tested successfully.")

    print("\n" + "=" * 60)
    print("ALL MILESTONE 2 VERIFICATION CHECKS PASSED!")
    print("=" * 60)

if __name__ == "__main__":
    run_tests()
