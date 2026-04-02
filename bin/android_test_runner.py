#!/usr/bin/env python3
"""
Runs a Flutter integration test on an Android device and determines pass/fail
by scanning stdout for the sentinels PASS, FAIL, or ERROR — consistent with
the string-signal pattern used by cloud_source_suite.dart and chrome_widget_runner.py.
"""
import argparse
import subprocess
import sys
import time
import signal
import os


def run_android_test(test_file, device_id, timeout_secs):
    cmd = [
        "flutter", "test",
        test_file,
        "-d", device_id,
    ]

    print(f"Starting Android Test Runner: {' '.join(cmd)}")
    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        preexec_fn=os.setsid,
    )

    success = None  # None = not yet determined by sentinel
    start = time.time()

    for line in iter(process.stdout.readline, ''):
        print(line, end='')

        if "PASS" in line:
            success = True
            break
        elif "FAIL" in line or "ERROR" in line:
            success = False
            break

        if time.time() - start > timeout_secs:
            print(f"\nTIMEOUT: test exceeded {timeout_secs}s")
            success = False
            break

    # Close stdout to force EOF and prevent pipe-related hangs,
    # then kill the process group and wait with a bounded timeout.
    try:
        process.stdout.close()
    except Exception:
        pass
    try:
        os.killpg(os.getpgid(process.pid), signal.SIGKILL)
    except ProcessLookupError:
        pass
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        pass  # Process refused to die — move on anyway

    # If no sentinel was seen, fall back to process exit code
    if success is None:
        success = (process.returncode == 0)

    return success


def main():
    parser = argparse.ArgumentParser(description="Android Integration Test Runner (string-sentinel aware)")
    parser.add_argument("-t", "--test", required=True, help="Integration test dart file to run")
    parser.add_argument("-d", "--device", required=True, help="Android device/emulator ID")
    parser.add_argument("--timeout", type=int, default=300, help="Timeout in seconds (default: 300)")
    args = parser.parse_args()

    if not run_android_test(args.test, args.device, args.timeout):
        os.system('stty sane')
        sys.exit(1)

    os.system('stty sane')


if __name__ == "__main__":
    main()
