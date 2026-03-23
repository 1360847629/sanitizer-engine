rule EICAR_Test_File {
    meta:
        description = "Standard EICAR Anti-Virus Test File"
        author = "Sanitizer Engine"
    strings:
        $eicar = "X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*"
    condition:
        $eicar
}

rule Suspicious_Script_Indicators {
    meta:
        description = "Detects common malicious script patterns (Webshells, Reverse Shells)"
    strings:
        $b64_eval = "eval(base64_decode" nocase
        $powershell_enc = "powershell -enc" nocase
        $rev_shell = "/bin/sh -i >& /dev/tcp"
    condition:
        any of them
}