#!/usr/bin/env python3
import subprocess
import sys
import time
import signal
import os
import time
import signal

def run_widget():
    cmd = [
        "flutter", "run",
        "-d", "chrome",
        "--dart-define=RUN_WIDGET=true"
    ]
    
    print(f"Starting Test Widget: {' '.join(cmd)}")
    # Launch in a new process group so we can cleanly kill the entire child tree later
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, preexec_fn=os.setsid)
    
    success = False
    finished = False
    
    # Read output line by line
    for line in iter(process.stdout.readline, ''):
        print(line, end='')
        if "PASS" in line:
            success = True
            finished = True
            break
        elif "FAIL" in line:
            success = False
            finished = True
            break
        elif "ERROR" in line:
            success = False
            finished = True
            break

    if finished:
        print("\n[Widget Completed] Shutting down Flutter runner...")
        # Give it a second to flush any remaining logs
        time.sleep(1)
        # Send literal 'q' to stdin to quit flutter cleanly if possible
        try:
            process.communicate(input='q\n', timeout=2)
        except:
            pass
            
        # Send SIGTERM to the entire process group (Flutter + Dart + Chrome)    
        try:
            os.killpg(os.getpgid(process.pid), signal.SIGTERM)
        except ProcessLookupError:
            pass
            
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(os.getpgid(process.pid), signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
        
        return success
    
    return process.returncode == 0

def main():
    print(f"\n==============================================")
    print(f"Launching Test Widget...")
    print(f"==============================================\n")
    
    if not run_widget():
        print(f"\n❌ Widget execution failed.")
        os.system('stty sane')
        sys.exit(1)
        
    print(f"\n✅ Test Widget sequence passed successfully!")
    os.system('stty sane')

if __name__ == "__main__":
    main()
