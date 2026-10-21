#!/bin/bash
# Same ignore sequence with Bazel's default spawn strategy.
# Fresh output base, so it cannot reuse the processwrapper-sandbox server.
# linux-sandbox is not available on Darwin.

cd "$(dirname "$0")"

printf 'vendored\n' > .bazelignore
printf 'original input\n' > vendored/flatcc/input.txt

output_base=$(mktemp -d)
echo "OUTPUT_BASE=$output_base"
echo "NOTE: no --spawn_strategy flag; Bazel chooses the host default."

b() {
  echo "+ bazelisk --ignore_all_rc_files --output_base=$output_base $*"
  bazelisk --ignore_all_rc_files --output_base="$output_base" "$@"
  status=$?
  echo "EXIT:$status"
  return $status
}

build() {
  b build --verbose_failures "$@"
}

echo "===== 1. establish old ignore state ====="
build //:seed
echo "SEED_EXIT:$?"

echo "===== 2. narrow ignore, first copy (expected fail) ====="
printf 'vendored/st\n' > .bazelignore
build //vendored/flatcc:copy
echo "FIRST_COPY_EXIT:$?"

echo "===== 3. identical retry (expected pass) ====="
build //vendored/flatcc:copy
echo "RETRY_COPY_EXIT:$?"
echo "===== copy.txt ====="
cat bazel-bin/vendored/flatcc/copy.txt
echo

echo "===== 4. settle, change input, query, build ====="
printf 'vendored\n' > .bazelignore
build //:seed
build //:seed
printf 'different input\n' > vendored/flatcc/input.txt
printf 'vendored/st\n' > .bazelignore
echo "+ bazelisk --ignore_all_rc_files --output_base=$output_base query //:seed >/dev/null"
b query //:seed >/dev/null
echo "QUERY_EXIT:$?"
build //vendored/flatcc:copy
echo "WORKAROUND_BUILD_EXIT:$?"
echo "===== copy.txt after workaround ====="
cat bazel-bin/vendored/flatcc/copy.txt
echo

echo "===== shutdown this output base only ====="
b shutdown
echo "SHUTDOWN_EXIT:$?"
