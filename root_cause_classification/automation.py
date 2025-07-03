import subprocess
import os
import re
import time
from pathlib import Path
from collections import defaultdict

# 경로 설정
CRASH_DIR = Path("./out/default/crashes")
OUT_DIR = Path("./asan_crashes")
HAR_EXEC = Path.cwd() / "har_afl"

# 실행파일 존재 확인
if not HAR_EXEC.exists():
    print(f"[!] 실행 파일 '{HAR_EXEC}' 을 찾을 수 없습니다.")
    exit(1)

OUT_DIR.mkdir(exist_ok=True)
name_counter = defaultdict(int)

# 패턴 정의
vuln_type_pattern = re.compile(r"ERROR: AddressSanitizer: ([\w\-]+)")
function_pattern = re.compile(r"#\d+\s+0x[0-9a-fA-F]+\s+in\s+.*::([a-zA-Z_][a-zA-Z0-9_]*)\(")

# 함수: 한 번 실행 및 분석
def analyze(crash_path):
    result = subprocess.run(
        [str(HAR_EXEC), str(crash_path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        env={**os.environ, "ASAN_OPTIONS": "abort_on_error=0"}
    )
    return result.stdout.strip().splitlines()

# 크래시 파일 순회
for crash_file in CRASH_DIR.iterdir():
    if not crash_file.name.startswith("id:"):
        continue

    output_lines = []
    root_cause = "unknown"
    vuln_type = "unknown-bug"

    for attempt in range(3):
        output_lines = analyze(crash_file)
        output_str = "\n".join(output_lines)

        # 취약점 유형 추출
        vuln_match = vuln_type_pattern.search(output_str)
        if vuln_match:
            vuln_type = vuln_match.group(1)

        # 루트커즈 함수 추출
        func_match = None
        for line in output_lines:
            func_match = function_pattern.search(line)
            if func_match:
                root_cause = func_match.group(1)
                break

        if root_cause != "unknown":
            break  # 성공했으면 중단
        else:
            time.sleep(0.5)  # 잠깐 딜레이 후 재시도

    if root_cause == "unknown":
        print(f"[?] {crash_file.name} → unknown (after 3 attempts)")
        print("    ─ ASan snippet ─")
        for line in output_lines[:12]:
            print("    ", line)
        print("    ────────────────")

    # 파일 이름 구성 및 저장
    base_name = f"{root_cause}_{vuln_type}"
    count = name_counter[base_name]
    name_counter[base_name] += 1

    filename = f"{base_name}.fbx" if count == 0 else f"{base_name}_{count}.fbx"
    dest_path = OUT_DIR / filename
    dest_path.write_bytes(crash_file.read_bytes())

    print(f"[+] {crash_file.name} → {filename}")