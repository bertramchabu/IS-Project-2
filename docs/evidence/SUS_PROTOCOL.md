# NetVision AI SUS Protocol

## Purpose

Measure perceived usability of the implemented NetVision AI dashboard with the
10-item System Usability Scale.

## Recruitment and consent

- Recruit consenting Strathmore administrative participants.
- Record only an anonymous participant ID.
- Obtain written consent before the session.
- Allow withdrawal without penalty.
- Do not invent or retain names.

## Session

1. Explain the simulation-only status of the threat module.
2. Ask the participant to sign in and use the role-appropriate dashboard.
3. Complete a CSV replay.
4. Observe an alert, acknowledge it and resolve it.
5. Complete the 10 SUS items.
6. Record the session length.

## Scoring

`score.py` applies odd-item positive scoring, even-item reverse scoring and
multiplies the sum by 2.5. The generated JSON includes n, mean, population
stddev and anonymous per-participant scores.

The repository's pre-existing 83.5/54.2 JSON values are retained as historical
stored values only. They must not be relabeled until real response rows exist.
