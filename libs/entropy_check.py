import sys
import math
from collections import Counter

def calculate_entropy(data):
    """Calculates the Shannon Entropy of a bytes object."""
    if not data:
        return 0.0
    
    total_len = len(data)
    counts = Counter(data)
    entropy = 0.0
    
    for count in counts.values():
        probability = count / total_len
        entropy -= probability * math.log2(probability)
        
    return entropy

if __name__ == "__main__":
    try:
        # 1. Parse Threshold (Default to 7.5 if not provided)
        try:
            max_entropy = float(sys.argv[1])
        except (IndexError, ValueError):
            max_entropy = 7.5

        # 2. Read Binary Data from Stdin (No Disk I/O)
        data = sys.stdin.buffer.read()
        
        # 3. Calculate Entropy
        entropy = calculate_entropy(data)
        
        # 4. Output result for logging and set Exit Code
        print(f"{entropy:.4f}")

        if entropy > max_entropy:
            sys.exit(1) # Threat Detected
        sys.exit(0)     # Safe
            
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)