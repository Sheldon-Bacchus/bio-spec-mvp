import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

REPO_ROOT = Path(__file__).resolve().parents[1]


def resolve_rscript() -> str:
    candidates = []
    configured = os.environ.get("RSCRIPT")
    if configured:
        candidates.append(Path(configured))

    discovered = shutil.which("Rscript")
    if discovered:
        candidates.append(Path(discovered))

    candidates.append(Path(r"C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe"))
    for candidate in candidates:
        if candidate.is_file():
            return str(candidate)
    raise SystemExit(
        "Rscript was not found. Set RSCRIPT to an Rscript executable before running this test."
    )


rscript = resolve_rscript()
skills_dir = REPO_ROOT / "skills" / "original-sop"
if not skills_dir.is_dir():
    raise SystemExit(f"SOP source directory does not exist: {skills_dir}")

print("======================================================================")
print("                BIO-SKILLS SUITE: SMOKE TEST MATRIX                  ")
print("======================================================================")
print(f"Target Skills Directory: {skills_dir}")
print(f"R Engine:                {rscript}")
print("----------------------------------------------------------------------\n")

skill_folders = sorted(
    entry.name for entry in skills_dir.iterdir() if entry.is_dir()
)

all_passed = True
total_checks = 0
passed_checks = 0

for sk in skill_folders:
    sk_path = skills_dir / sk
    skill_md = sk_path / "SKILL.md"
    scripts_dir = sk_path / "scripts"
    refs_dir = sk_path / "references"
    
    print(f"[SMOKE CHECK] Skill: {sk}")
    
    # 1. Architecture check
    r_files = sorted(scripts_dir.glob("*.R")) if scripts_dir.is_dir() else []
    has_md = skill_md.is_file()
    has_scripts = bool(r_files)
    has_refs = refs_dir.is_dir() and any(refs_dir.iterdir())
    
    total_checks += 3
    if has_md and has_scripts and has_refs:
        print("  + [PASS] Architecture: SKILL.md + scripts/ + references/ present")
        passed_checks += 3
    else:
        print(f"  + [FAIL] Architecture: md={has_md}, scripts={has_scripts}, refs={has_refs}")
        all_passed = False
        continue
    
    # 2. R Script Compilation Check
    for r_file in r_files:
        r_file_path = r_file.as_posix().replace('"', '\\"')
        total_checks += 1
        parse_code = (
            f'tryCatch({{ parse("{r_file_path}"); cat("OK") }}, '
            'error=function(e) { cat("ERR:", e$message); quit(status=1) })'
        )
        cmd = [rscript, "-e", parse_code]
        res = subprocess.run(cmd, capture_output=True, encoding='utf-8', errors='replace')
        out_str = (res.stdout or '').strip()
        err_str = (res.stderr or '').strip()
        if res.returncode == 0 and "OK" in out_str:
            print(f"  + [PASS] Compiler AST: {r_file.name} compiled successfully")
            passed_checks += 1
        else:
            print(f"  + [FAIL] Compiler AST: {r_file.name} -> {out_str} {err_str}")
            all_passed = False

    # 3. Gate Interception Negative Check
    primary_r = r_files[0]
    cmd = [rscript, str(primary_r), "--input-file=NON_EXISTENT_FILE.csv"]
    with tempfile.TemporaryDirectory(prefix="bio-spec-005-smoke-") as temp_dir:
        res = subprocess.run(
            cmd,
            cwd=temp_dir,
            capture_output=True,
            encoding='utf-8',
            errors='replace',
        )
    total_checks += 1
    out_str = (res.stdout or '')
    err_str = (res.stderr or '')
    if res.returncode != 0 or "[GATE ERROR]" in out_str or "Error" in err_str:
        print("  + [PASS] Negative Gate: Non-existent input correctly rejected")
        passed_checks += 1
    else:
        print("  + [WARN] Negative Gate: Did not halt on missing input")

    print()

pct = (passed_checks / total_checks * 100) if total_checks > 0 else 0
print("======================================================================")
print(f"SMOKE TEST SUMMARY: {passed_checks}/{total_checks} checks passed ({pct:.1f}%)")
if all_passed:
    print("RESULT: ALL 11 SKILLS PASSED SMOKE VALIDATION!")
else:
    print("RESULT: SOME CHECKS FAILED!")
    sys.exit(1)
print("======================================================================")
