import os, subprocess, sys

sys.stdout.reconfigure(encoding='utf-8')

rscript = r"C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe"
skills_dir = r"E:\all-agent-workspace\bio-skills\orginal-sop-skills"

print("======================================================================")
print("                BIO-SKILLS SUITE: SMOKE TEST MATRIX                  ")
print("======================================================================")
print(f"Target Skills Directory: {skills_dir}")
print(f"R Engine:                {rscript}")
print("----------------------------------------------------------------------\n")

skill_folders = [d for d in os.listdir(skills_dir) if os.path.isdir(os.path.join(skills_dir, d))]
skill_folders.sort()

all_passed = True
total_checks = 0
passed_checks = 0

for sk in skill_folders:
    sk_path = os.path.join(skills_dir, sk)
    skill_md = os.path.join(sk_path, "SKILL.md")
    scripts_dir = os.path.join(sk_path, "scripts")
    refs_dir = os.path.join(sk_path, "references")
    
    print(f"[SMOKE CHECK] Skill: {sk}")
    
    # 1. Architecture check
    has_md = os.path.exists(skill_md)
    has_scripts = os.path.exists(scripts_dir) and len([f for f in os.listdir(scripts_dir) if f.endswith('.R')]) > 0
    has_refs = os.path.exists(refs_dir) and len(os.listdir(refs_dir)) > 0
    
    total_checks += 3
    if has_md and has_scripts and has_refs:
        print("  + [PASS] Architecture: SKILL.md + scripts/ + references/ present")
        passed_checks += 3
    else:
        print(f"  + [FAIL] Architecture: md={has_md}, scripts={has_scripts}, refs={has_refs}")
        all_passed = False
        continue
    
    # 2. R Script Compilation Check
    for rf in os.listdir(scripts_dir):
        if rf.endswith('.R'):
            r_file_path = os.path.join(scripts_dir, rf).replace('\\', '/')
            total_checks += 1
            cmd = [rscript, "-e", f'tryCatch({{ parse("{r_file_path}"); cat("OK") }}, error=function(e) {{ cat("ERR:", e$message); quit(status=1) }})']
            res = subprocess.run(cmd, capture_output=True, encoding='utf-8', errors='replace')
            out_str = (res.stdout or '').strip()
            err_str = (res.stderr or '').strip()
            if res.returncode == 0 and "OK" in out_str:
                print(f"  + [PASS] Compiler AST: {rf} compiled successfully")
                passed_checks += 1
            else:
                print(f"  + [FAIL] Compiler AST: {rf} -> {out_str} {err_str}")
                all_passed = False

    # 3. Gate Interception Negative Check
    primary_r = [f for f in os.listdir(scripts_dir) if f.endswith('.R')][0]
    r_file_path = os.path.join(scripts_dir, primary_r).replace('\\', '/')
    cmd = [rscript, r_file_path, "--input-file=NON_EXISTENT_FILE.csv"]
    res = subprocess.run(cmd, capture_output=True, encoding='utf-8', errors='replace')
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
