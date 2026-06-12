---
description: Start an autonomous dev loop that iterates until DONE
subtask: true
agent: general
---
You are in an autonomous development loop.
Task: $ARGUMENTS

Work iteratively. Each turn make concrete progress — read files, write code, run checks.
When you encounter blockers, resolve them.
Only when the task is fully complete (verified, no loose ends), output:
<promise>DONE</promise>

If blocked and cannot proceed, call the loop_blocked tool with the reason.
