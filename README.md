# `.bazelignore` update is missed by a live Bazel 9.2.0 server

TLDR: Changing `.bazelignore` from `vendored` to `vendored/st` does not make `vendored/flatcc/input.txt` available to the next build on an existing bazel server. The genrule fails because of a missing file input from the execroot, but subsequent builds succeed correctly. Running `bazel query` of an unrelated target before that build also makes the first attempt succeed, and the action runs on the updated input.

To reproduce, all we need is a `genrule` that copies one text file.

## My Environment

| | |
|---|---|
| OS | macOS 26.6.2 (build 25G83) |
| Kernel | Darwin 25.6.0, `RELEASE_ARM64_T8142` |
| Architecture | arm64 |
| Bazelisk | 1.29.0 (`/opt/homebrew/bin/bazelisk`) |
| Bazel | 9.2.0 |
| Build target | `@@//src/main/java/com/google/devtools/build/lib/bazel:BazelServer` |
| Build time | Mon Jul 13 18:19:39 2026 (1783966779) |
| Recorded | Wed Oct 21 17:48:32 CDT 2026 |

also using ignore all rc files so that local config doesn't cause this.

I also reproduced this on a nixOS linux image, so I don't think this is an os-specific issue. (Was not able to test on Windows).

## Commands

You can reproduce if you have bazelisk on your machine by running `run.sh` and `run-default-sandbox.sh` 

The script that produced the log is `evidence/run.sh`. Output base: `/var/folders/qq/497d7tcs3835cj30nnfqc0900000gn/T/tmp.ALMeFvB7CP`. Full log: `evidence/processwrapper.log`.

## Processwrapper-sandbox

First `//vendored/flatcc:copy` failed, exit 1:

```text
(cd /private/var/folders/qq/497d7tcs3835cj30nnfqc0900000gn/T/tmp.ALMeFvB7CP/sandbox/processwrapper-sandbox/2/execroot/_main && \
  exec env - \
    PATH=/bin:/usr/bin:/usr/local/bin \
  /bin/bash -c 'source external/bazel_tools/tools/genrule/genrule-setup.sh; /bin/cat vendored/flatcc/input.txt > bazel-out/darwin_arm64-fastbuild/bin/vendored/flatcc/copy.txt')
cat: vendored/flatcc/input.txt: No such file or directory
```

But doing a retry worked correctly with no server restart. `bazel-bin/vendored/flatcc/copy.txt` was:

```text
original input
```

## Query workaround, same server

`.bazelignore` was restored to `vendored` and `//:seed` was built twice. `input.txt` was then changed to `different input`, `.bazelignore` was narrowed to `vendored/st` again, and `b query //:seed` was run before the copy build.

That first copy build succeeded

```text
different input
```

That output is the updated file, so the success is not a cache hit on the earlier `original input` result.

## Default sandbox

`run-default-sandbox.sh` repeated the same sequence on a new output base and bazel auto selected darwin-sandbox. The results were identical to above.

## Implications

This is detrimental to CI contexts where we may have long-running Bazel servers and a queued PR job might fail because of transient error from Bazel's caching. Jobs can incorrectly fail when on a new checkout with a modifed `.bazelignore`.