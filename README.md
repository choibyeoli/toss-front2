# Portable Qualcomm EDL / fastbootd / GSI toolkit

이 폴더 하나를 다른 PC로 복사해 사용할 수 있도록 만들었다. 모든 실행 파일은 자신의 위치를 기준으로 경로를 계산하므로 `C:\Users\...` 같은 개인 경로를 포함하지 않는다.

## 폴더 구조

```text
portable-qualcomm-edl-gsi/
├─ run/                         # 번호 순서대로 실행하는 CMD 파일
├─ scripts/                     # PowerShell 구현부
├─ tools/
│  ├─ edl/                      # edl.py와 edlclient 폴더를 넣는다
│  │  ├─ edl.py
│  │  └─ firehose.elf           # 대상 기기에 맞는 Firehose programmer
│  └─ platform-tools/           # Google platform-tools 전체를 넣는다
│     └─ fastboot.exe
├─ inputs/
│  ├─ gsi/system.img            # 설치할 GSI
│  └─ patches/                  # 대상 기기에서 검증한 패치 파일
│     ├─ patch-plan.json
│     ├─ debug-flags.json
│     ├─ bcb.json
│     └─ <원본/수정 바이너리>
├─ backups/                     # 자동 생성: 읽기 전 백업과 EDL 덤프
└─ logs/                        # 자동 생성: 실행 로그
```

## 처음 사용할 때

1. `tools/edl/`에 bkerler EDL 도구 전체와 **대상 기기에 맞는** `firehose.elf`를 넣는다.
2. `tools/platform-tools/`에 Android platform-tools 전체를 넣는다.
3. 대상 기기를 EDL로 연결할 수 있도록 WinUSB/libusb 드라이버를 설정한다.
4. 대상 기기에서 전체 LUN/GPT 백업을 만든 뒤, 그 백업은 이 폴더 밖의 안전한 위치에도 보관한다.
5. `inputs/patches/`의 JSON 템플릿을 대상 기기의 GPT·블록 크기·패치 파일에 맞춰 채운다.
6. GSI를 `inputs/gsi/system.img`에 둔다.

## 실행 순서

`run` 폴더에서 아래 순서대로 실행한다.

1. `01-edl-info.cmd` — EDL 연결과 GPT 확인
2. `02-patch-preflight.cmd` — 패치 대상이 예상한 원본 해시와 일치하는지 확인
3. `03-patch-apply.cmd` — 기기별 `init`/ABL/AVB 패치 적용 및 읽기 검증
4. `04-set-debug-flags.cmd` — 설정 저장소의 디버그 플래그 적용 및 읽기 검증
5. `05-boot-fastbootd.cmd` — BCB로 fastbootd 요청 후 EDL 리셋
6. `06-flash-gsi.cmd` — GSI logical partition 정리·플래시·선택적 wipe

문제가 생기면 EDL로 다시 연결하고 `07-patch-restore.cmd`로 패치 범위만 원복할 수 있다. 전체 부팅 불능이면 대상 기기에서 만든 전체 LUN 백업으로 복구한다.

## JSON 파일의 역할

- `patch-plan.json`: `init`, ABL, `vbmeta` 등 기기별 바이너리 패치의 LUN·섹터·원본/변경 파일·SHA-256을 정의한다.
- `debug-flags.json`: 디버그 설정이 있는 저장소 블록과 바이트 범위를 정의한다. `smraw`는 한 기기의 사례일 뿐, 모든 기기에 존재하지 않는다.
- `bcb.json`: `misc` 안의 BCB 블록 위치와 논리 블록 크기를 정의한다.
- `gsi-plan.json`: GSI 설치 전 삭제할 logical partition 및 wipe 여부를 정의한다.

## 중요한 제한

- 이 도구는 대상 기기용으로 검증된 입력 파일이 있어야만 쓰기를 허용한다.
- 해시가 다르면 적용을 중단한다. 억지로 해시 검사를 끄지 않는다.
- `ABL`, `init`, `vbmeta`는 다른 기기 또는 다른 빌드의 파일을 재사용하지 않는다.
- `fastboot -w`는 잠긴 기기에서 거부될 수 있다. `gsi-plan.json`의 wipe 항목은 기본적으로 꺼져 있다.
- logical partition 삭제는 부팅 불능을 만들 수 있다. GSI 크기와 `super` group 용량을 먼저 계산한다.
