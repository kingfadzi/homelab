#!/usr/bin/env python3
import os, sys, json, time
import requests

API_BASE = os.environ.get("OPENAI_BASE_URL", "https://api.openai.com")
API_KEY  = os.environ.get("OPENAI_API_KEY")

def fail(msg, code=1):
    print(f"❌ {msg}", file=sys.stderr)
    sys.exit(code)

def get_headers():
    if not API_KEY:
        fail("OPENAI_API_KEY is not set in your environment.")
    return {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
    }

def show_ratelimit_headers(resp):
    # Print common RL headers if present
    hdrs = resp.headers
    keys = [
        "x-ratelimit-limit-requests",
        "x-ratelimit-remaining-requests",
        "x-ratelimit-limit-tokens",
        "x-ratelimit-remaining-tokens",
        "retry-after",
    ]
    present = {k: hdrs[k] for k in keys if k in hdrs}
    if present:
        print("↳ Rate-limit headers:", json.dumps(present, indent=2))

def pretty_error(resp):
    try:
        data = resp.json()
    except Exception:
        data = {"raw": resp.text}
    return json.dumps(data, indent=2)

def diag_from_error(resp):
    status = resp.status_code
    body = {}
    try:
        body = resp.json()
    except Exception:
        pass

    err_type = body.get("error", {}).get("type")
    err_code = body.get("error", {}).get("code")
    err_msg  = body.get("error", {}).get("message", "")

    print(f"\nHTTP {status} — error type={err_type!r} code={err_code!r}")
    print(err_msg or resp.text)
    show_ratelimit_headers(resp)

    if status == 401:
        fail("Diagnosis: Invalid API key or not authorized for this resource.", 2)

    if status == 429:
        # Distinguish rate limit vs insufficient quota
        if err_code == "insufficient_quota" or "quota" in err_msg.lower():
            print("Diagnosis: ❗ Insufficient quota / billing block (not rate limit).")
            print("What to check:")
            print("  • Billing → Payment method is active and verified")
            print("  • Billing → Usage limits: HARD limit not set to $0")
            print("  • Using the correct *project* key that belongs to a paid account")
            print("  • If you recently added billing, try again (sometimes a brief delay)")
            sys.exit(3)
        else:
            print("Diagnosis: ⚠️ Rate limit (RPM/TPM). Slow down or add backoff.")
            sys.exit(4)

    # Other common statuses
    if status in (400, 404):
        print("Diagnosis: Bad request or resource not found (model name / params?).")
        sys.exit(5)

    if status >= 500:
        print("Diagnosis: Server-side issue. Retry with backoff.")
        sys.exit(6)

    sys.exit(7)

def sanity_check_models():
    print("→ Checking /v1/models …")
    resp = requests.get(f"{API_BASE}/v1/models", headers=get_headers(), timeout=30)
    if resp.status_code != 200:
        print("Models list failed.")
        print(pretty_error(resp))
        diag_from_error(resp)
    data = resp.json()
    count = len(data.get("data", []))
    print(f"✅ Models reachable ({count} models returned).")

def tiny_chat_test():
    print("→ Running a tiny chat completion …")
    url = f"{API_BASE}/v1/chat/completions"
    payload = {
        "model": "gpt-4o-mini",     # small/cheap; change to what you actually use
        "messages": [{"role": "user", "content": "Say 'pong'."}],
        "max_tokens": 5,
        "temperature": 0,
    }
    resp = requests.post(url, headers=get_headers(), json=payload, timeout=60)

    if resp.status_code == 200:
        out = resp.json()
        text = out["choices"][0]["message"]["content"]
        print(f"✅ Chat success. Model replied: {text!r}")
        return

    print(pretty_error(resp))
    diag_from_error(resp)

def main():
    print(f"API base: {API_BASE}")
    if not API_KEY:
        fail("OPENAI_API_KEY is missing.")
    if API_KEY.startswith("sk-"):
        print("Key format: legacy user key (sk-)")
    elif API_KEY.startswith("sk-proj-"):
        print("Key format: project-scoped key (sk-proj-)")
    else:
        print("Key format: unrecognized prefix (may still be valid).")

    sanity_check_models()
    tiny_chat_test()
    print("\n✅ All checks passed. You should be able to use the API normally.")

if __name__ == "__main__":
    main()
