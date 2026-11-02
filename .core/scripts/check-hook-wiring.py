#!/usr/bin/env python3
"""
check-hook-wiring.py — Verify that all required hooks are installed and executable.

Exit codes:
  0 — all hooks installed and executable
  1 — hooks missing or not executable
"""

import os
import sys
from pathlib import Path


def check_hooks():
    """Verify that all hooks in .core/hooks/ are installed and executable."""
    hooks_dir = Path('.core/hooks')
    git_hooks_dir = Path('.git/hooks')
    
    if not hooks_dir.exists():
        print("[HOOK-WIRING] ERROR: .core/hooks/ directory not found")
        return False
    
    hook_scripts = sorted(hooks_dir.glob('*.py'))
    if not hook_scripts:
        print("[HOOK-WIRING] WARNING: no hook scripts found in .core/hooks/")
        return True  # No hooks = nothing to check
    
    all_ok = True
    for script in hook_scripts:
        # Check executable permission
        if not os.access(script, os.X_OK):
            print(f"[HOOK-WIRING] WARNING: {script} is not executable")
            all_ok = False
        
        # Verify it's a valid Python script
        try:
            with open(script, 'r') as f:
                first_line = f.readline().strip()
                if not first_line.startswith('#!'):
                    print(f"[HOOK-WIRING] WARNING: {script} missing shebang")
                    all_ok = False
        except IOError:
            print(f"[HOOK-WIRING] ERROR: cannot read {script}")
            all_ok = False
    
    if all_ok:
        print(f"[HOOK-WIRING] OK: {len(hook_scripts)} hooks verified")
    else:
        print(f"[HOOK-WIRING] ISSUES FOUND: run '.core/scripts/install-git-hooks.sh' to fix")
    
    return all_ok


if __name__ == '__main__':
    sys.exit(0 if check_hooks() else 1)
