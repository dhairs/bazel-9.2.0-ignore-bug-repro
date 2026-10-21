#!/bin/bash
# Reproduce the .bazelignore stale-state bug on one persistent Bazel server.
# Do not use set -e: the first //vendored/flatcc:copy failure is intentional.

cd "$(dirname "$0")"
repo=$(pwd)

{
  echo "===== environment ====="
  date
  uname -a
  sw_vers
  echo "repo=$repo"
  echo "bazelisk=$(command -v bazelisk)"
  bazelisk version
} | tee evidence/environment.txt

output_base=$(mktemp -d)
echo "OUTPUT_BASE=$output_base" | tee evidence/output-base.txt

b() {
  echo "+ bazelisk --ignore_all_rc_files --output_base=$output_base $*"
  bazelisk --ignore_all_rc_files --output_base="$output_base" "$@"
  status=$?
  echo "EXIT:$status"
  return $status
}

build() {
  b build --spawn_strategy=processwrapper-sandbox --verbose_failures "$@"
}

echo "===== 1. establish old ignore state ====="
printf 'vendored\n' > .bazelignore
build //:seed
echo "SEED_EXIT:$?"

echo "===== 2. stop ignoring the parent directory ====="
printf 'vendored/st\n' > .bazelignore
echo "bazelignore now:"
cat -e .bazelignore

echo "===== 3. first copy build (expected: fail, input.txt missing) ====="
build //vendored/flatcc:copy
echo "FIRST_COPY_EXIT:$?"

echo "===== 4. identical retry (expected: pass, no restart) ====="
build //vendored/flatcc:copy
echo "RETRY_COPY_EXIT:$?"
echo "===== bazel-bin/vendored/flatcc/copy.txt ====="
cat bazel-bin/vendored/flatcc/copy.txt
echo
echo "RETRY_CAT_EXIT:$?"

echo "===== 5. restore and settle the old ignore state ====="
printf 'vendored\n' > .bazelignore
build //:seed
echo "SETTLE_1_EXIT:$?"
build //:seed
echo "SETTLE_2_EXIT:$?"

echo "===== 6. change input, narrow ignore, query, then build ====="
printf 'different input\n' > vendored/flatcc/input.txt
printf 'vendored/st\n' > .bazelignore
echo "input.txt now:"
cat -e vendored/flatcc/input.txt
echo "bazelignore now:"
cat -e .bazelignore
echo "+ bazelisk --ignore_all_rc_files --output_base=$output_base query //:seed >/dev/null"
b query //:seed >/dev/null
echo "QUERY_EXIT:$?"
build //vendored/flatcc:copy
echo "WORKAROUND_BUILD_EXIT:$?"
echo "===== bazel-bin/vendored/flatcc/copy.txt after workaround ====="
cat bazel-bin/vendored/flatcc/copy.txt
echo
echo "WORKAROUND_CAT_EXIT:$?"

echo "===== bazel version (same server) ====="
b version
b info release

echo "===== shutdown this output base only ====="
b shutdown
echo "SHUTDOWN_EXIT:$?"
