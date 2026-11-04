---
name: SSH Debug
description: Diagnose GitHub SSH failures like Permission denied (publickey) on git push, fetch, or ssh -T git@github.com
---

## Workflow

Diagnose in this order. Run one test at a time — repeated rapid
`ssh -T` attempts can trigger GitHub rate limiting and produce
misleading intermittent failures.

1. Confirm the remote actually uses SSH:
   `git remote -v` (look for `git@github.com:...`, not `https://...`).
2. Inspect client config: `cat ~/.ssh/config` — note the
   `IdentityFile` under `Host github.com`, and whether
   `IdentitiesOnly yes` is set.
3. Compare agent vs disk: `ssh-add -l` against `ls ~/.ssh/*.pub`.
   A stale agent entry for a deleted key file is a classic failure.
4. Single auth test: `ssh -o ConnectTimeout=10 -T git@github.com`.
   Expect `Hi <user>! ...` with exit 1. Exit 255 means auth failed.
5. If step 4 fails, isolate the agent from the equation:
   `SSH_AUTH_SOCK="" ssh -o IdentitiesOnly=yes -i <private-key> -T git@github.com`.
   Success here but failure with the agent means a stale/wrong
   agent identity — `ssh-add -D` then re-add only the valid key.
6. Verify the offered key is the registered key:
   `ssh -vv -T git@github.com` shows each `Offering public key`.
   Compare fingerprints with `ssh-keygen -lf <pubkey>` and
   `ssh-keygen -y -f <private-key>` (proves private matches public).
7. Verify against GitHub: `gh ssh-key list` must show the same key
   material as an `authentication` key. Needs the
   `admin:public_key` scope — if it 404s, run
   `gh auth refresh -h github.com -s admin:public_key -s admin:ssh_signing_key`
   (interactive, user runs it in their own terminal).
8. Flaky pattern (identical command alternately succeeds/fails):
   suspect replication delay after a fresh key upload, or a
   port-22 problem. Test the documented fallback:
   `ssh -o StrictHostKeyChecking=accept-new -T -p 443 git@ssh.github.com`.
   If 443 works and 22 does not, pin it in `~/.ssh/config`:
   `Hostname ssh.github.com` + `Port 443` under `Host github.com`.
9. Commit-signing fallout: after rotating keys, check
   `git config --global user.signingkey` still points at an existing
   `.pub` file, and `gpg.ssh.allowedSignersFile` does not point at a
   deleted/company-managed file. Roundtrip test:
   `echo test | ssh-keygen -Y sign -f <pubkey> -n test`.

## Config hygiene for Host github.com

- One `IdentityFile` pointing at the valid key; add
  `IdentitiesOnly yes` so no other agent key is offered.
- Agent holds only currently valid keys (`ssh-add -D`, re-add).
- `~/.ssh/config`, `user.signingkey`, and `allowedSignersFile`
  must all reference files that still exist on disk.
