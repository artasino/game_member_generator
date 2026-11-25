"""Add a short release note to the changelog bundled in the Web build."""

import json
import re
import subprocess
import sys
from pathlib import Path


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def release_changes():
    parents = git("rev-list", "--parents", "-n1", "HEAD").split()[1:]
    tags = (
        git("tag", "--merged", parents[0], "--sort=-version:refname").splitlines()
        if parents else []
    )
    previous = next(
        (tag for tag in tags if re.fullmatch(r"v\d+\.\d+\.\d+", tag)), ""
    )
    revision = f"{previous}..HEAD" if previous else "HEAD"
    commits = git("log", "--first-parent", "-5", "--format=%s%x00%b%x1e", revision)
    changes = []
    for commit in commits.split("\x1e"):
        subject, _, body = commit.strip().partition("\x00")
        if subject.startswith("Merge pull request "):
            subject = next(
                (line.strip() for line in body.splitlines() if line.strip()), subject
            )
        if subject and subject not in changes:
            changes.append(subject)
    return changes


def main(version, date):
    changelog = Path("assets/changelog.json")
    notes = json.loads(changelog.read_text(encoding="utf-8"))
    if any(note["version"] == version for note in notes):
        return
    changes = release_changes()
    if changes:
        notes.insert(0, {"version": version, "date": date, "changes": changes})
        changelog.write_text(
            json.dumps(notes, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )


if __name__ == "__main__":
    main(*sys.argv[1:])
