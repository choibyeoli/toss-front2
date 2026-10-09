# 실제 동작 확인가이드

대상: Qualcomm EDL(9008), A/B 슬롯, `super` dynamic partition을 쓰는 Android 기기  
목적: 디버그 모드를 켜고 EDL에서 fastbootd로 진입해 GSI `system.img`를 플래시한다.

## 핵심

이번 방식의 핵심은 두 가지다.

1. 설정 저장소(예: `smraw`)의 디버그 값을 `true`로 쓴다.
2. ABL이 그 값을 읽은 뒤 다시 `false`로 덮어쓰는 코드를 패치한다.

그 뒤 EDL에서 fastbootd로 들어가 GSI를 플래시하면 된다. USB 역할이나 `adbd`를 따로 수정하는 것은 기본 절차에 필요하지 않았다.

> ABL·설정 저장소의 위치·패치 바이트·Firehose는 기기별로 다르다. 다른 기기의 파일, 섹터 주소, 해시를 그대로 쓰면 안 된다.

## 준비

- EDL 진입 가능한 대상 기기와 WinUSB/libusb 드라이버
- 대상 기기에 맞는 `firehose.elf`
- `edl.py`와 Android platform-tools
- 설치할 GSI `system.img`
- **대상 기기에서 만든 전체 UFS/eMMC 백업과 GPT 백업**

전체 백업은 반드시 먼저 만든다. `persist`, modem/NV, 보안·식별 영역은 다른 기기 백업으로 대체하지 않는다.

## 1. 전체 백업

패치나 GSI 작업 전에 EDL에서 모든 physical LUN을 통째로 백업한다. 이 백업이 부팅 불능 시 가장 확실한 복구 지점이다.

1. EDL INFO로 저장장치 보고서와 GPT를 읽는다.
2. 각 LUN의 전체 섹터 수를 확인한다.
3. `storage-plan.json`에 모든 LUN 번호와 섹터 수를 넣고 `enabled`를 `true`로 바꾼다.
4. FULL BACKUP을 실행한다.

백업은 `backups/full-storage-날짜/`에 `lun0.bin`, `lun1.bin` 등의 덤프와 `manifest.json`을 만든다. manifest에는 파일 크기와 SHA-256이 기록된다.

## 2. 디버그 플래그 위치 확인

구버전 또는 디버그가 동작하는 빌드와 최신 빌드의 설정 저장소를 비교한다. 디버그 ON/OFF 전후 바뀌는 블록과 문자열을 찾아 다음을 확인한다.

```text
SYSDEBUGMODE=true
APPDEBUGMODE=true
```

해당 smraw 파일의 값은 각 0x300, 0x400에 있음.
설정값이 `true`인데도 부팅 후 디버그가 꺼져 있으면, 다음 단계인 ABL을 확인한다.

## 3. ABL의 강제 false 처리 제거

최신 ABL과 이전 정상 ABL을 비교해 디버그 설정을 읽은 직후 `false`를 쓰는 로직을 찾는다. 해당 로직만 패치하거나, 대상 빌드와 호환되는 이전 ABL을 사용한다.

쓰기는 항상 다음 순서로 한다.

1. 라이브 ABL을 읽어 원본 SHA-256 확인
2. 수정본을 기록
3. 같은 범위를 다시 읽어 수정본 SHA-256 확인

이 단계까지 적용하고 부팅했을 때 디버그 표시가 유지되면 기본 패치는 끝이다.

### OS가 다시 끄는 경우

일부 펌웨어는 Android `init`도 디버그 값을 다시 `false`로 바꾼다. 이 경우에만 `system`의 `init`을 패치하고, 수정된 `system`과 맞는 `vbmeta_system`도 함께 적용한다.

`adbd`, USB 역할 설정은 건드리지 않는다.

## 4. EDL에서 fastbootd 부팅

ADB가 필요 없다. EDL에서 `misc`의 BCB(Bootloader Control Block)에 `boot-fastboot` 명령을 기록하고, 읽기 검증 뒤 기기를 리셋한다.

PC에서 다음을 확인한다.

```powershell
fastboot devices
fastboot getvar is-userspace
```

아래처럼 나오면 fastbootd다.

```text
<serial>    fastboot
is-userspace: yes
```

설치가 끝난 뒤에는 BCB를 원래 값 또는 빈 값으로 복원한다. 그렇지 않으면 계속 fastbootd로 부팅될 수 있다.

## 5. GSI 플래시

GSI가 현재 `system_<slot>`보다 크면, 같은 `super` group에서 공간을 확보해야 한다. 기기에서 검증된 순서는 다음과 같다.

```powershell
# fastbootd에서 실행
fastboot -w

fastboot delete-logical-partition product_a
fastboot delete-logical-partition product_b
fastboot delete-logical-partition system_ext_a
fastboot delete-logical-partition system_ext_b

fastboot flash system system.img
fastboot -w
fastboot reboot
```

위 파티션 삭제 목록은 **이 기기의 GSI 설치 사례**다. 다른 기기에서는 `super` 구성과 GSI 요구사항을 확인한 뒤 필요한 파티션만 정한다.

`fastboot -w`가 잠긴 상태에서 거부되는 기기도 있다. 이는 `system` 플래시 가능 여부와 별개일 수 있으며, OEM·fastbootd 구현에 따라 다르다.
다만 fastboot 명령어는 위에서 디버그 모드를 키는 것만으로도 언락되는 것을 확인하였음.

## 6. 복구

부팅 루프나 로고 반복이 생기면 EDL로 다시 진입한다.

1. 패치 범위만 되돌릴 수 있으면 PATCH RESTORE를 실행한다.
2. `misc`의 BCB를 원래 값 또는 빈 값으로 복원한다.
3. 그래도 부팅하지 않으면 FULL RESTORE를 실행하고, FULL BACKUP 때 생성된 폴더를 입력한다.

FULL RESTORE는 manifest의 SHA-256을 먼저 검사한 뒤 모든 LUN을 복원하고, primary GPT가 들어 있는 LUN 0을 마지막에 기록한다. 작업 전 `RESTORE ALL`을 입력해야 시작된다.

도너 기기의 전체 저장소를 대상에 복사해 복구하지 않는다.

## 포터블 실행 도구

[portable-qualcomm-edl-gsi](portable-qualcomm-edl-gsi) 폴더는 다른 PC로 그대로 복사해 쓸 수 있다. 개인 PC 경로를 쓰지 않는다.

```text
portable-qualcomm-edl-gsi/
├─ RUN_TOOLKIT.cmd               # 단일 키보드 메뉴
├─ tools/
│  ├─ edl/                       # edl.py, edlclient, 대상 기기용 firehose.elf
│  └─ platform-tools/            # Google platform-tools 전체
├─ inputs/
│  ├─ gsi/system.img             # 설치할 GSI
│  └─ patches/                   # 기기별 패치 파일과 JSON 계획
├─ inputs/storage-plan.json       # 전체 LUN 백업/복원 계획
├─ backups/                      # 자동 생성
└─ logs/                         # 자동 생성
```

### 파일을 넣을 위치

- `tools/edl/`: `edl.py`, `edlclient` 폴더, 대상 기기용 `firehose.elf`
- `tools/platform-tools/`: `fastboot.exe`를 포함한 platform-tools 전체
- `inputs/gsi/system.img`: GSI 이미지
- `inputs/patches/`: 기기별 원본/수정 바이너리와 JSON 계획 파일

`inputs/storage-plan.json`에는 대상 저장장치의 모든 physical LUN과 각 LUN의 전체 섹터 수를 넣는다. `inputs/patches/patch-plan.json`에는 ABL 또는 선택적 `init` 패치의 LUN·섹터·원본/수정 파일·SHA-256을 넣는다. `debug-flags.json`에는 디버그 설정 저장소의 위치와 값 필드를 넣는다. `bcb.json`에는 `misc` BCB 위치를 넣는다.

템플릿은 기본적으로 비활성화되어 있다. 대상 기기의 위치와 해시를 채우기 전에는 쓰기 단계가 실행되지 않는다.

### 단일 메뉴 사용

`RUN_TOOLKIT.cmd`를 열고 키보드로 선택한다.

| 키 | 작업 |
| --- | --- |
| `1` | EDL 연결과 GPT 확인 |
| `2` | 전체 LUN 백업과 SHA-256 manifest 생성 |
| `3` | 패치 원본 해시 검사 |
| `4` | ABL/선택적 `init`/AVB 패치 적용 |
| `5` | 디버그 플래그 설정 |
| `6` | EDL에서 fastbootd 부팅 |
| `7` | GSI 플래시 |
| `8` | 패치 범위 원복 |
| `9` | 전체 LUN 복원 |
| `Q` | 종료 |

권장 순서는 `1 → 2 → 3 → 4 → 5 → 6 → 7`이다.
