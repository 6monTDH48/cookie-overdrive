#!/bin/sh
# One command: regenerate the API/bundle and run the scenario. Exit 1 on failure.
cd "$(dirname "$0")" && python3 gen.py >/dev/null && /home/user/tools/luau -O2 scenario.luau > out/last_run.log 2>&1
status=$?
tail -40 out/last_run.log
grep -q "RESULT: PASS" out/last_run.log && [ $status -eq 0 ]
