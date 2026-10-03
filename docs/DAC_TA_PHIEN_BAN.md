# Đặc tả phiên bản – Lab 0 System Call (xv6)

## 1. Đề có nói gì về phiên bản không?

Đề bài (`Lab0_System_Call.pdf`) **không** ghi chuẩn C hay phiên bản compiler. Tài liệu cài đặt (`Setup-lab.pdf`) thì có ghi, và repo của nhóm cho biết phần còn lại:

| Nguồn | Nội dung | Suy ra |
|---|---|---|
| `Lab0_System_Call.pdf` | `git checkout syscall`, link `6.1810/2023/labs/syscall.html` | Bộ **xv6-labs** của MIT, nhánh **syscall**, kiến trúc **RISC-V** |
| `Setup-lab.pdf` | `git clone git://g.csail.mit.edu/xv6-labs-2024`, QEMU **7.2+**, GDB **8.3+**, **Ubuntu 24** | Môn học dùng **xv6-labs-2024** |
| Repo của nhóm | Commit gốc `d5b09ff "syscall lab"` (09/2024), có sẵn `user/trace.c`, `user/attack.c`, `user/secret.c` | Repo đúng là **xv6-labs-2024, nhánh syscall** |

Kết luận: link 2023 trong đề chỉ là tài liệu tham khảo. Nhóm làm trên **bản 2024** như repo hiện có. Với bài `trace`, hai bản gần như giống hệt nhau.

Code mẫu trong PDF (`int sys_hello(void)`, `#include "user.h"`) **không khớp** với bản 2024. Nó được viết theo kiểu xv6 cũ, nên chỉ dùng để hiểu ý tưởng, **đừng chép nguyên**.

## 2. "C mới hay C cũ"? Thật ra là hai chuyện khác nhau

### a) Chuẩn ngôn ngữ C (C99, C17…)

Chuẩn C do **Makefile** của xv6 quyết định, qua biến `CFLAGS`. **Không tự sửa nó.**

- Makefile của repo này **không** ghi `-std=`, nên GCC dùng chuẩn mặc định của nó. GCC 13 mặc định là gnu17.
- Makefile có `-Werror`: **mọi cảnh báo đều thành lỗi**. Ví dụ khai báo biến mà không dùng cũng làm build hỏng.

Code của lab này chỉ dùng C cơ bản (struct, mảng, phép bit, printf), nên chuẩn nào cũng chạy giống nhau.

### b) Phiên bản mã nguồn xv6

**Đây mới là chỗ khiến code khác nhau:**

| | xv6 cũ (x86 / RISC-V đời đầu) | xv6 mới (2022 trở đi, gồm labs-2024) |
|---|---|---|
| Kiểu trả về của hàm `sys_*` | `int` | `uint64` |
| `argint()` | trả về `int` (0 hoặc -1) | trả về `void` |
| Mảng `syscalls[]` | `static int (*syscalls[])(void)` | `static uint64 (*syscalls[])(void)` |

**Nguyên tắc:** viết theo đúng repo đang dùng. Cách dễ nhất là nhìn các hàm `sys_*` có sẵn (ví dụ `sys_getpid`) và viết giống y kiểu đó.

## 3. Đặc tả nhóm thống nhất sử dụng

| Thành phần | Quy định |
|---|---|
| Mã nguồn | **xv6-labs-2024**, nhánh `syscall`. Repo nhóm: `github.com/HieuLe832/OS_syscall`, nhánh `main` |
| Commit gốc (để tạo patch) | `d5b09ff`, cũng chính là nhánh `origin/original/syscall` |
| Kiến trúc | RISC-V 64-bit (`rv64gc`) |
| Môi trường build | **Ubuntu 24.04** trong Docker (`Dockerfile` ở thư mục gốc repo) |
| Compiler | `riscv64-linux-gnu-gcc` 13.x |
| Binutils | `riscv64-linux-gnu` 2.42 |
| Trình giả lập | `qemu-system-riscv64` 8.2.x (Setup-lab.pdf yêu cầu tối thiểu 7.2) |
| Debugger | `gdb-multiarch` 15.x (Setup-lab.pdf yêu cầu tối thiểu 8.3) |
| Chuẩn C | Theo Makefile của repo, **không sửa `CFLAGS`** |
| Hàm syscall | `uint64 sys_xxx(void)` |
| Lấy tham số | `argint(n, &x);` (kiểu void) |
| Định dạng output | `syscall <tên> -> <giá trị>`, **không in PID** (theo PDF môn học) |

## 4. Vì sao chọn như vậy?

- **Khớp với đề.** Dockerfile cài **đúng danh sách gói** mà Setup-lab.pdf đưa ra cho Ubuntu 24 (`git build-essential gdb-multiarch qemu-system-misc gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu`). Phiên bản QEMU và GDB đều vượt mức tối thiểu đề yêu cầu.
- **Đã kiểm chứng.** Với image này, repo build không lỗi, boot vào shell `$`, và lời giải `trace` cho đúng output như PDF.
- **Ghim phiên bản để cả nhóm giống nhau.** Ba người dùng ba máy khác nhau dễ gặp cảnh "máy tao chạy được, máy mày không". Docker giúp ba người dùng **cùng một compiler**.
- **Tránh compiler quá mới.** GCC 15 (trên các distro rất mới) mặc định dùng chuẩn C23. Makefile không ghi `-std=` và có `-Werror`, nên code C cũ dễ bị lỗi biên dịch. Ghim Ubuntu 24.04 (GCC 13) tránh được rủi ro này.

## 5. Kiểm tra repo đang dùng đúng bản

Chạy các lệnh sau trong thư mục repo:

```bash
git log --oneline -1 origin/original/syscall   # → d5b09ff syscall lab
cat conf/lab.mk                                # → LAB=syscall
grep -n "argint" kernel/defs.h                 # → void argint(int, int*);  (bản mới)
grep -n "sys_getpid" kernel/sysproc.c -B1      # → uint64 (bản mới)
ls user/trace.c user/attack.c                  # bản 2024 có sẵn cả hai file
```

## 6. Cách dùng Docker

### Bước 1 – Cài Docker

- **Windows/macOS:** cài Docker Desktop.
- **Linux:** cài Docker Engine.

### Bước 2 – Build image (mỗi máy chỉ làm 1 lần)

`Dockerfile` nằm sẵn ở thư mục gốc repo. Đứng ở thư mục gốc repo rồi chạy:

```bash
docker build -t xv6-env .
```

> `Dockerfile` và thư mục `docs/` là file riêng của nhóm, **không phải bài làm**. Chúng được loại ra khỏi file patch và file zip nộp bài bằng lệnh ở mục 9 của `Huong_dan_Lab0_trace.md`.

### Bước 3 – Chạy container, mount mã nguồn xv6 vào

Đứng **ở thư mục gốc repo** rồi chạy lệnh tương ứng.

**Linux / macOS / WSL:**
```bash
docker run -it --rm --name xv6 -v "$(pwd)":/xv6 --user "$(id -u):$(id -g)" xv6-env
```

**Windows PowerShell:**
```powershell
docker run -it --rm --name xv6 -v "${PWD}:/xv6" xv6-env
```

Code nằm trên máy thật, nên vẫn sửa bằng VS Code như bình thường. Container chỉ dùng để build và chạy.

Tham số `--user` giúp các file do `make` tạo ra thuộc về bạn thay vì root, để sau này xóa được dễ dàng.

> **Lưu ý:** lệnh `docker run` **chỉ đưa bạn vào container** (một máy Ubuntu có sẵn compiler). Nó **chưa chạy xv6**. Lúc này dấu nhắc có dạng:
> ```
> I have no name!@a1b2c3:/xv6$
> ```
> - `I have no name!`: tên user. Do dùng `--user` nên container không biết tên bạn. Vô hại.
> - `a1b2c3`: ID của container.
> - `/xv6`: thư mục hiện tại. Đây **chính là thư mục repo trên máy thật**, được mount vào nhờ `-v`.
>
> Phải làm tiếp Bước 4 thì mới vào được xv6.

### Bước 4 – Build và chạy xv6 trong container

```bash
make clean    # chỉ cần khi mới clone, đổi nhánh hoặc trước khi nộp bài
make qemu     # build rồi boot xv6
```

Boot xong sẽ thấy `init: starting sh` và dấu nhắc chỉ còn **`$ ` trơn**. Đó là shell **của xv6**, chạy bên trong QEMU. Từ đây mới gõ được `ls`, `grep`, `trace`… của xv6.

Có **hai tầng**, đừng nhầm hai dấu `$`:

| | Bash của container | Shell của xv6 |
|---|---|---|
| Dấu nhắc | `I have no name!@a1b2c3:/xv6$` | `$ ` |
| Vào bằng | `docker run ...` | `make qemu` |
| Chạy được | `make`, `git`… (lệnh Linux) | `ls`, `grep`, `trace`… (chương trình xv6) |
| Thoát | gõ `exit` → về máy thật | **Ctrl-A** rồi **X** → về bash container |

Sửa code xong thì thoát xv6 (Ctrl-A, X) rồi chạy lại `make qemu`. Không cần thoát container hay chạy lại `docker run`.

Lúc build sẽ thấy vài dòng `warning: ... has a LOAD segment with RWX permissions`. Đây là cảnh báo của linker, **không phải lỗi**, bỏ qua được.

### Bước 5 – Kiểm tra phiên bản (đối chiếu với mục 3)

```bash
riscv64-linux-gnu-gcc --version
qemu-system-riscv64 --version
gdb-multiarch --version
```

### (Tuỳ chọn) Debug bằng GDB

**Terminal 1**, trong container:
```bash
make qemu-gdb
```

**Terminal 2**, trên máy thật:
```bash
docker exec -it xv6 gdb-multiarch -x .gdbinit
```

## 7. Lưu ý theo hệ điều hành

**Windows:**
- Phải dùng **WSL 2**. Setup-lab.pdf ghi rõ WSL 1 không chạy được lab. Kiểm tra bằng `wsl -l -v` trong Windows Terminal.
- Trước khi clone, chạy `git config --global core.autocrlf false`. Nếu không, git đổi xuống dòng sang CRLF và các script `.pl` / `.sh` có thể bị lỗi.
- Nên để repo trong ổ của WSL (ví dụ `~/xv6`), không để trong `C:\`. Mount từ ổ Windows vào container chạy rất chậm.

**macOS chip Apple (M1/M2/M3):** nếu `docker build` báo không tìm thấy gói, build lại theo kiến trúc x86. Cách này chạy chậm hơn nhưng chắc chắn được:
```bash
docker build --platform linux/amd64 -t xv6-env .
docker run --platform linux/amd64 -it --rm --name xv6 -v "$(pwd)":/xv6 xv6-env
```
Nếu không dùng Docker, Setup-lab.pdf có hướng dẫn cài bằng Homebrew (`brew install riscv-tools qemu`).

## 8. Khác biệt giữa đề môn học và đề gốc MIT

| Điểm | Đề MIT 2024 | Đề môn học (PDF) | Nhóm làm theo |
|---|---|---|---|
| Định dạng output | Có PID: `3: syscall read -> 1023` | Không PID: `syscall read -> 1023` | **Đề môn học** |
| Copy mask khi `fork()` | Bắt buộc | Không nhắc | **Vẫn làm**: đúng ý đề gốc và không ảnh hưởng output mẫu |
| Phần "Using gdb" (`answers-syscall.txt`) | Có | Không có | **Không làm** |
| Phần "Attack xv6" (`attack.c`) | Có | Không có | **Không làm**. Các file `attack`, `attacktest`, `secret` có sẵn trong repo, cứ để nguyên |
| Kiểm tra kết quả | `make grade` | So với output trong PDF | **So tay với PDF**. `make grade` của MIT tìm định dạng có PID và chấm cả phần gdb, attack, nên sẽ báo FAIL dù bài đúng |
| Số byte của các dòng `read` | — | `1023, 966, 70, 0` | Repo này ra `1023, 971, 298, 0` vì file `README` của bản 2024 dài hơn. **Không phải lỗi** |
