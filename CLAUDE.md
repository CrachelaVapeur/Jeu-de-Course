# Rules for every Claude working on this project

Read this file at the start of every session, then follow it. It is shared
by the Claudes of Eric, Willy and Maximo, so that all three work the same way.

## The project

- An arcade 3D racing game with an original sci-fi universe (in the spirit
  of Redline, Alita's Motorball and Borderlands), made in **Godot 4.7**.
- Team: **Eric** and **Willy** (French), **Maximo** (Spanish and English).
  All three are learning; explain what you do in simple words.
- **Language:** talk to each person in their own language (Eric and Willy:
  French; Maximo: Spanish or English). The shared files of the process
  (this file, `CONVENTIONS.md`, `docs/playtest_todo.md`, pull request
  descriptions) are written in **English**, so that everyone can read them.
  The code itself (names, comments) stays in French, like the existing code.

## Where things live

- **Game design:** the master document « 00 Document maître (GDD) » in the
  Google Drive folder « Projet jeu Eric & Willy », with the session reports.
  It is the reference for design decisions. An idea from one person goes to
  « Idées en attente »; it becomes a « Décision validée » only when the team
  agrees. If you cannot reach the Drive, ask your person.
- **Code and assets:** this repository. `main` is the shared base everyone
  starts from.
- **What to test by hand:** `docs/playtest_todo.md`.

## Git rules

1. **Never commit or push directly to `main`.** One branch per task, then a
   pull request.
2. **Start every task from the latest `main`** (pull it first). Before opening
   a pull request, merge the latest `main` into your branch again.
3. **When merging, never undo someone else's work by accident.** If your
   branch is older than `main`, Git may show their changes as "removed" in
   your diff. Read the diff of your pull request: it must only contain your
   own changes. Tuning values (speeds, boost, colours…) agreed with the team
   must not be changed silently.
4. A pull request is merged only when its person says so ("merge"). Changes
   to the shared process (this file, `CONVENTIONS.md`) need everyone's
   agreement.
5. Describe in the pull request what changed and what was tested.

## Before every pull request

- Run the check: `outils/verifier.sh` (Linux, Mac) or
  `outils\verifier.ps1` (Windows), with the `GODOT` environment variable
  pointing to the Godot 4.7 executable (on Windows, the "console" build).
  It must end with "All good".
- If the change can be felt in the game, add a line to
  `docs/playtest_todo.md`: what to try and what should happen. Only a human
  can judge whether it is fun; the check only proves nothing is broken.
- Give your person the controls and what to look at when they try it.

## Working conventions

See `CONVENTIONS.md`.
