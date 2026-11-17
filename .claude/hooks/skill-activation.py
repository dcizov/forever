#!/usr/bin/env python3
"""UserPromptSubmit hook: suggest the skills a prompt needs, before Claude answers.

Adapted from the "detection hook + trigger rules" fix (dev.to, oluwawunmiadesewa;
hook system after diet103's infrastructure showcase), rewritten in stdlib Python
because this machine has no node/tsx. Rules live in skill-rules.json beside this
file. Prints nothing when no rule matches, so ordinary prompts cost no context.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RULES = os.path.join(HERE, "skill-rules.json")
ORDER = {"critical": 0, "high": 1, "medium": 2, "low": 3}
# IDE context blocks: scan their file paths, not their code (code would trigger everything).
IDE_BLOCK = re.compile(r"<(ide_selection|ide_opened_file|ide_diagnostics)>(.*?)</\1>", re.S)
PATH = re.compile(r"[\w./-]+\.(?:lua|toc|xml)\b")


def word_re(phrase):
    return re.compile(r"(?<![\w])" + re.escape(phrase.lower()) + r"(?![\w])")


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    prompt = data.get("prompt") or ""
    if not prompt.strip() or prompt.lstrip().startswith("/"):
        return  # a slash command already names its skill

    with open(RULES, encoding="utf-8") as fh:
        rules = json.load(fh)

    blocks = [m.group(2) for m in IDE_BLOCK.finditer(prompt)]
    text = IDE_BLOCK.sub(" ", prompt)
    lower = text.lower()
    paths = PATH.findall(text) + [p for b in blocks for p in PATH.findall(b)]

    hits = []
    for name, rule in rules.get("skills", {}).items():
        why = None
        for kw in rule.get("keywords", []):
            if word_re(kw).search(lower):
                why = '"%s"' % kw
                break
        if not why:
            for pat in rule.get("intentPatterns", []):
                if re.search(pat, text, re.I):
                    why = "request wording"
                    break
        if not why:
            for pat in rule.get("casePatterns", []):
                m = re.search(pat, text)
                if m:
                    why = m.group(0)
                    break
        if not why:
            for pat in rule.get("pathPatterns", []):
                p = next((p for p in paths if re.search(pat, p)), None)
                if p:
                    why = p
                    break
        if why:
            hits.append((ORDER.get(rule.get("priority"), 2), name, why, rule))

    if not hits:
        return
    hits.sort(key=lambda h: h[0])
    hits = hits[: rules.get("maxSuggestions", 6)]

    lines = []
    if any(h[3].get("wow", True) for h in hits):
        for gate in rules.get("wowGate", {}).get("with", []):
            if gate not in (h[1] for h in hits):
                lines.append("- %s (always first for WoW API work; target Forever)" % gate)
    for _, name, why, rule in hits:
        note = rule.get("note")
        lines.append("- %s (matched %s)%s" % (name, why, "; " + note if note else ""))

    context = (
        "SKILL CHECK (skill-activation hook): this prompt matches these skills:\n"
        + "\n".join(lines)
        + "\nIf the task touches what a listed skill covers, call the Skill tool for it before "
        "writing code or answering; skip one already loaded in this conversation or plainly "
        "irrelevant (a keyword false positive). docs/forever-api.md and CLAUDE.md still win."
    )
    json.dump({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit",
                                      "additionalContext": context}}, sys.stdout)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # never block a prompt over a hook bug
        sys.stderr.write("skill-activation: %s\n" % exc)
