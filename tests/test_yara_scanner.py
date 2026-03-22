import yara
import os
import sys

# Path to the YARA rules file
RULES_FILE = os.path.join(os.path.dirname(__file__), 'dev/rules.yar')

# Standard EICAR test string (matches the rule in dev/rules.yar)
TEST_PAYLOAD = "X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*"

def main():
    # 1. Verify Rules File Exists
    if not os.path.exists(RULES_FILE):
        print(f"[!] Error: Rules file not found at: {RULES_FILE}")
        sys.exit(1)

    print(f"[*] Loading rules from: {RULES_FILE}")

    try:
        # 2. Compile Rules
        rules = yara.compile(filepath=RULES_FILE)
        
        # 3. Scan the Test Payload
        print(f"[*] Scanning sample payload (EICAR signature)...")
        matches = rules.match(data=TEST_PAYLOAD)

        # 4. Report Results
        if matches:
            print(f"\n[+] SUCCESS: Detection verified.")
            print(f"    Triggered Rules: {[match.rule for match in matches]}")
        else:
            print(f"\n[-] FAILURE: No matches found in known malicious sample.")
            sys.exit(1)
            
    except Exception as e:
        print(f"[!] Execution Error: {e}")

if __name__ == "__main__":
    main()