#!/bin/bash
# Usage: ./run_random.sh [number_of_seeds]   (default 200)
N=${1:-200}; PASS=0; FAIL=0
mkdir -p build
for s in $(seq 1 $N); do
  python3 tools/gen_random.py $s 200 > build/rand.s
  if ./run.sh build/rand.s > build/rand.log 2>&1; then PASS=$((PASS+1));
  else FAIL=$((FAIL+1)); echo "seed $s FAILED (program saved as build/fail_$s.s)"; cp build/rand.s build/fail_$s.s; fi
done
echo "random tests: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
