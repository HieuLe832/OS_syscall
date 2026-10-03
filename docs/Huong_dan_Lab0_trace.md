# Hướng dẫn Lab 0 – System Call `trace` (xv6)

Tài liệu gồm hai phần. Phần A giúp cả nhóm hiểu kiến thức nền. Phần B là phân công, code cụ thể, cách test và nộp bài.

> Bài được chấm qua **vấn đáp**, theo mức hiểu code của từng người. Ai cũng phải nắm được **toàn bộ luồng**, không chỉ phần mình làm.

---

# PHẦN A – HIỂU KIẾN THỨC NỀN

## 1. System call là gì?

Hãy hình dung hệ điều hành như một **ngân hàng**:

- **Chương trình của bạn (user program)** là khách hàng.
- **Kernel** là nhân viên quầy.
- **Phần cứng, ổ đĩa, bộ nhớ của tiến trình khác** là kho tiền. Khách không được tự đi vào.

Muốn đọc file, tạo tiến trình hay in ra màn hình, khách phải "điền phiếu yêu cầu" ở quầy. Phiếu đó chính là **system call**.

Mỗi loại phiếu có một **số hiệu**, định nghĩa trong `kernel/syscall.h`. Ví dụ: `read` = 5, `exec` = 7, `open` = 15.

Có hai "thế giới" tách biệt nhau:

| | User space | Kernel space |
|---|---|---|
| Thư mục | `user/` | `kernel/` |
| Ai chạy | chương trình thường (grep, ls, trace…) | hệ điều hành |
| Quyền | hạn chế | toàn quyền |

## 2. Đường đi của một system call trong xv6

Ví dụ chương trình gọi `trace(32)`:

```
[USER]   user/trace.c gọi trace(32)
            │  hàm trace() thực chất là một "stub" trong user/usys.S
            │  (file này do user/usys.pl tự sinh ra khi chạy make)
            ▼
         li a7, SYS_trace   ← ghi số hiệu syscall (22) vào thanh ghi a7
         ecall              ← "bấm chuông": CPU chuyển sang chế độ kernel
─────────────────────────────────────────────────────────────
[KERNEL] usertrap() (kernel/trap.c)
            │  thanh ghi của user được lưu vào p->trapframe
            ▼
         syscall() (kernel/syscall.c)
            │  đọc a7 → num = 22 → tra bảng syscalls[22]
            ▼
         sys_trace() (kernel/sysproc.c)
            │  lấy tham số bằng argint(0, &mask) (tham số đầu nằm ở a0)
            ▼
         giá trị trả về được ghi vào p->trapframe->a0
─────────────────────────────────────────────────────────────
[USER]   quay về user, trace(32) trả về giá trị trong a0
```

Các thanh ghi cần nhớ:

- **a7**: số hiệu system call.
- **a0, a1, …, a5**: các tham số truyền vào.
- **a0** sau khi về: giá trị trả về.

**Điểm mấu chốt:** **mọi** system call đều đi qua hàm `syscall()`. Nó giống một **trạm thu phí** mà xe nào cũng phải qua. Đây là chỗ lý tưởng để in log trace, vì tại đây ta biết cả **số hiệu** lẫn **giá trị trả về** của mọi syscall.

## 3. Đề bài yêu cầu gì?

Đề có hai yêu cầu chính:

1. Thêm system call `trace(int mask)`. Nó ghi nhớ `mask` cho **tiến trình đã gọi nó**.
2. Mỗi khi một syscall sắp trả về, nếu số hiệu của nó được bật trong mask, kernel in ra:
   ```
   syscall <tên> -> <giá trị trả về>
   ```

Ngoài ra cần chương trình `user/trace.c`. Nó gọi `trace(mask)` rồi `exec` chương trình cần theo dõi.

### Mask (bitmask) là gì?

`mask` là một số nguyên. **Mỗi bit đại diện cho một syscall**: bit thứ `i` bật nghĩa là "theo dõi syscall số `i`". Kernel kiểm tra bằng phép:

```c
mask & (1 << num)    // khác 0 → syscall num đang được theo dõi
```

| Syscall | Số hiệu | Giá trị mask (1 << số hiệu) |
|---|---|---|
| fork | 1 | 2 |
| exit | 2 | 4 |
| wait | 3 | 8 |
| read | 5 | 32 |
| exec | 7 | 128 |
| open | 15 | 32768 |
| write | 16 | 65536 |
| close | 21 | 2097152 |
| trace | 22 | 4194304 |

Một số ví dụ:

- `32` = nhị phân `100000`, tức bit 5 bật. Chỉ `read` được theo dõi.
- `32 + 65536 = 65568` theo dõi cả `read` lẫn `write`.
- `2147483647` = 2³¹ − 1 bật hết bit 0 đến 30, nên theo dõi tất cả.

### Giải thích output mẫu

```
$ trace 2147483647 grep hello README
syscall trace -> 0      ← chính lời gọi trace(), mask vừa set xong nên nó cũng bị in
syscall exec -> 3       ← exec trả về argc = 3 (grep, hello, README)
syscall open -> 3       ← grep mở file README, được file descriptor 3
syscall read -> 1023
syscall read -> 966
syscall read -> 70
syscall read -> 0       ← đọc hết file
syscall close -> 0
```

> **Lưu ý:** trên repo của nhóm (bản 2024), ba dòng `read` ra `1023`, `971`, `298` thay vì `1023`, `966`, `70`. Lý do là file `README` của bản 2024 dài hơn. Đây **không phải lỗi**; chỉ cần dòng cuối là `read -> 0`.

**Vì sao grep bị theo dõi?** `exec` thay toàn bộ code của tiến trình bằng code của grep, nhưng **vẫn là tiến trình đó** (cùng `struct proc`). Vì vậy `trace_mask` vẫn còn nguyên.

**Vì sao `grep hello README` chạy thường thì không in gì?** Shell tạo tiến trình mới cho grep, và tiến trình đó có mask = 0.

---

# PHẦN B – LÀM BÀI

## 4. Chuẩn bị môi trường (cả nhóm)

**Bước 1.** Lấy repo của nhóm:
```bash
git clone https://github.com/HieuLe832/OS_syscall.git
cd OS_syscall
```
Nhánh `main` của repo này **đã là code nhánh `syscall`** của xv6-labs-2024, nên **không cần** `git checkout syscall` như trong đề. Code gốc của MIT được giữ ở nhánh `origin/original/syscall` để so sánh và tạo patch.

**Bước 2.** Chuẩn bị công cụ. Chọn **một** trong hai cách:

- **Cách 1 – Docker (khuyên dùng, cả nhóm cùng phiên bản):** làm theo mục 6 của `docs/DAC_TA_PHIEN_BAN.md`. Tóm tắt:
  ```bash
  docker build -t xv6-env .
  docker run -it --rm --name xv6 -v "$(pwd)":/xv6 --user "$(id -u):$(id -g)" xv6-env
  ```
- **Cách 2 – Cài thẳng lên Ubuntu 24 hoặc WSL 2** (theo Setup-lab.pdf):
  ```bash
  sudo apt-get update && sudo apt-get upgrade
  sudo apt-get install git build-essential gdb-multiarch qemu-system-misc gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu
  ```

> `docker run` chỉ đưa bạn vào container (dấu nhắc `...:/xv6$`), **chưa vào xv6**. Phải làm tiếp Bước 3.

**Bước 3.** Chạy thử (trong container nếu dùng Docker):
```bash
make clean
make qemu
```
Thấy `init: starting sh` và dấu nhắc `$` là được. Gõ `ls` sẽ thấy các chương trình như `cat`, `grep`, `attack`, `secret`… nhưng **chưa có `trace`**. Thoát QEMU bằng **Ctrl-A** rồi bấm **X**.

**Bước 4 (nên làm).** Đọc Chương 2 và mục 4.3, 4.4 của xv6 book, như đề yêu cầu.

## 5. Quy ước chung (thống nhất TRƯỚC khi code)

| Quy ước | Giá trị |
|---|---|
| Số hiệu syscall | `SYS_trace = 22` |
| Tên biến trong `struct proc` | `trace_mask` |
| Định dạng in | `syscall %s -> %d\n` (đúng như PDF, **không** in PID) |

> **Lưu ý phiên bản:** PDF viết `int sys_hello(void)` theo bản xv6 cũ. Repo của nhóm là bản **2024**, dùng `uint64`, và `argint()` không trả về giá trị. Code dưới đây viết cho bản 2024 và **đã chạy thử thành công** trên repo này.

## 6. Phân công

| Người | Phần code | File phụ trách | Phần report tự viết | Việc chung |
|---|---|---|---|---|
| **Người 1** | Nối đường từ user vào kernel | `user/user.h`, `user/usys.pl`, `Makefile`, `kernel/syscall.h`, đọc hiểu `user/trace.c` (có sẵn) | Phần 3 (phía user) + Phần 5 (kết quả test) | **Test**, **ghép report** thành PDF |
| **Người 2** | Kernel: tạo syscall và lưu mask | `kernel/proc.h`, `kernel/sysproc.c`, `kernel/proc.c` | Phần 2 (tổng quan luồng syscall) + Phần 4a (lưu mask) | Kiểm tra lại bản report cuối |
| **Người 3** | Kernel: đăng ký syscall và in log | `kernel/syscall.c` | Phần 4b (in log) | **Merge code**, tạo patch và zip |

Dàn ý report và cách chia phần xem ở mục 9. Ai cũng tự viết phần "Khó khăn" của mình.

Ba người sửa **các file khác nhau**, nên làm song song được mà không đụng nhau.

Vì sao chia như vậy:
- **Người 3 chỉ có 1 file, nhưng đó là file chính** của bài. Người 3 sửa 3 chỗ trong `syscall.c`: đăng ký syscall vào bảng, thêm bảng tên, và thêm dòng in log trong `syscall()`. Phần in log là yêu cầu trọng tâm của đề. Merge, tạo patch và zip mất khoảng 15 phút, nên Người 3 chỉ viết một phần report.
- **Người 1 ít code nhất**, nên nhận test và ghép report. Phần ghép gồm trang bìa, bảng phân công, ráp các phần lại, định dạng và xuất PDF.
- **Người 2** viết phần tổng quan luồng syscall, phần dài nhất về lý thuyết. Phần này thuận tay vì Người 2 làm `sys_trace` và `argint`, nằm giữa luồng.

**Phối hợp:** hai dòng sau tuy ngắn nhưng người khác cần chúng mới build được, nên **đẩy lên đầu tiên**:
- Người 1: `#define SYS_trace 22` trong `syscall.h` (Người 3 cần nó cho bảng `syscalls[]`).
- Người 2: `int trace_mask;` trong `proc.h` (Người 3 cần nó cho dòng `if` in log).

---

### 👤 Người 1 – Nối đường từ user vào kernel + test + ghép report

**a) `kernel/syscall.h`**: thêm số hiệu mới:
```c
#define SYS_trace 22
```
File này nằm trong `kernel/` nhưng **cả hai phía cùng dùng**: stub trong `usys.S` (phía user) include nó để biết số đặt vào a7, còn `syscall.c` (phía kernel) dùng nó để tra bảng.

**b) `user/user.h`**: thêm khai báo hàm, đặt cạnh các syscall khác:
```c
int trace(int);
```

**c) `user/usys.pl`**: thêm dòng cuối danh sách:
```perl
entry("trace");
```
Dòng này khiến make sinh ra trong `usys.S` một đoạn stub: `li a7, SYS_trace` → `ecall` → `ret`.

**d) `Makefile`**: thêm vào danh sách `UPROGS` **đầu tiên**, ngay dưới dòng `$U/_zombie\`:
```
	$U/_zombie\
	$U/_trace\
```
Đừng thêm vào các khối `UPROGS += ...` nằm trong `ifeq ($(LAB),...)` phía dưới. Dòng thụt đầu phải là **Tab**, không phải dấu cách.

**e) `user/trace.c`**: **MIT đã cho sẵn file này** trong repo bản 2024, **không cần viết lại**. Việc của Người 1 là đọc hiểu nó:
```c
#include "kernel/param.h"     // có MAXARG (số tham số tối đa của exec)
#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

int
main(int argc, char *argv[])
{
  int i;
  char *nargv[MAXARG];

  // cần ít nhất: trace <mask> <lệnh>, và mask phải bắt đầu bằng chữ số
  if(argc < 3 || (argv[1][0] < '0' || argv[1][0] > '9')){
    fprintf(2, "Usage: %s mask command\n", argv[0]);
    exit(1);
  }

  // argv[1] là mask dạng chuỗi → atoi đổi sang số → gọi syscall trace
  if (trace(atoi(argv[1])) < 0) {
    fprintf(2, "%s: trace failed\n", argv[0]);
    exit(1);
  }

  // chép argv[2], argv[3], ... sang nargv[0], nargv[1], ...
  for(i = 2; i < argc && i < MAXARG; i++){
    nargv[i-2] = argv[i];
  }
  nargv[argc-2] = 0;          // danh sách tham số của exec phải kết thúc bằng 0
  exec(nargv[0], nargv);

  // exec thành công thì KHÔNG BAO GIỜ chạy tới đây
  printf("trace: exec failed\n");
  exit(0);
}
```

Ví dụ với `trace 32 grep hello README`: `argv = {"trace", "32", "grep", "hello", "README"}`, nên `nargv = {"grep", "hello", "README", 0}`.

**✅ Người 1 phải hiểu được:**
- Vì sao `kernel/types.h` phải include trước `user/user.h`? Vì user.h dùng các kiểu như `uint` được định nghĩa trong types.h.
- `usys.pl` và `usys.S` liên quan thế nào? Script perl sinh ra file assembly chứa các stub.
- Vì sao chưa sửa gì mà build đã hỏng khi thêm `$U/_trace` vào Makefile? Vì `trace.c` gọi `trace()` nhưng chưa có khai báo trong user.h và stub trong usys.pl.
- Vì sao code sau `exec` chỉ chạy khi exec lỗi? Vì exec thành công sẽ thay toàn bộ code của tiến trình.
- Vì sao `nargv[0]` là tên chương trình (`grep`) chứ không phải tham số đầu? Vì theo quy ước, phần tử đầu của danh sách tham số là tên chương trình.
- Số 22 trong `syscall.h` đi qua những đâu? Từ `usys.S` (`li a7, SYS_trace`) vào thanh ghi a7, rồi `syscall()` đọc a7 để tra bảng.

**f) Test (sau khi ghép code):** chạy các lệnh ở mục 7, chụp ảnh cho report. Sau đó thử **cố tình gây lỗi** theo bảng ở mục 8, ví dụ bỏ `entry("trace")` hoặc bỏ dòng copy mask trong `fork()`, để thấy triệu chứng thật. Làm trên branch nháp, xong thì bỏ. Cách này giúp cả nhóm trả lời tốt câu hỏi "nếu thiếu X thì sao?" lúc vấn đáp.

**g) Report:** viết Phần 3 và Phần 5. Sau đó nhận phần của hai người kia, ghép lại thành bản cuối và xuất PDF (xem mục 9).

---

### 👤 Người 2 – Kernel: tạo syscall và lưu mask + report

**a) `kernel/proc.h`**: thêm biến vào trong `struct proc`:
```c
int trace_mask;    // bitmask các syscall cần trace
```

**b) `kernel/sysproc.c`**: viết hàm xử lý:
```c
uint64
sys_trace(void)
{
  int mask;
  argint(0, &mask);              // lấy tham số thứ 0 (thanh ghi a0)
  myproc()->trace_mask = mask;   // lưu vào tiến trình đang chạy
  return 0;
}
```

**c) `kernel/proc.c`**: sửa hai chỗ.

Trong hàm `fork()`, tìm chỗ copy thông tin từ cha (`p`) sang con (`np`), ví dụ gần dòng `np->sz = p->sz;`. Thêm:
```c
np->trace_mask = p->trace_mask;   // con kế thừa mask của cha
```

Trong hàm `freeproc()`, cạnh các dòng như `p->pid = 0;`, thêm:
```c
p->trace_mask = 0;   // dọn dẹp để tiến trình sau dùng lại slot không bị dính mask cũ
```

**✅ Người 2 phải hiểu được:**
- `myproc()` trả về gì? Con trỏ đến `struct proc` của tiến trình đang chạy.
- Vì sao lưu mask trong `struct proc`? Mỗi tiến trình có struct riêng, nên trace chỉ ảnh hưởng tiến trình đã gọi nó, đúng yêu cầu đề.
- `argint(0, &mask)` lấy dữ liệu từ đâu? Từ `p->trapframe->a0`, nơi user đã đặt tham số trước khi `ecall`.
- Vì sao cần copy trong `fork()` và reset trong `freeproc()`?

**d) Report:** viết Phần 2 (tổng quan luồng syscall) và Phần 4a (lưu mask), xem mục 9. Khi Người 1 ghép xong, Người 2 đọc lại toàn bộ bản cuối.

---

### 👤 Người 3 – Kernel: đăng ký syscall và in log + merge code, đóng gói

**a) `kernel/syscall.c`**: khai báo hàm và đăng ký vào bảng.

Thêm cạnh các dòng `extern` khác:
```c
extern uint64 sys_trace(void);
```

Trong mảng `syscalls[]`, thêm:
```c
[SYS_trace]   sys_trace,
```

**b) `kernel/syscall.c`**: thêm mảng tên syscall, đặt **sau** mảng `syscalls[]`.

Cú pháp `[SYS_x]` đặt mỗi tên đúng vị trí theo số hiệu, nên không sợ sai thứ tự:
```c
static char *syscall_names[] = {
[SYS_fork]   "fork",
[SYS_exit]   "exit",
[SYS_wait]   "wait",
[SYS_pipe]   "pipe",
[SYS_read]   "read",
[SYS_kill]   "kill",
[SYS_exec]   "exec",
[SYS_fstat]  "fstat",
[SYS_chdir]  "chdir",
[SYS_dup]    "dup",
[SYS_getpid] "getpid",
[SYS_sbrk]   "sbrk",
[SYS_sleep]  "sleep",
[SYS_uptime] "uptime",
[SYS_open]   "open",
[SYS_write]  "write",
[SYS_mknod]  "mknod",
[SYS_unlink] "unlink",
[SYS_link]   "link",
[SYS_mkdir]  "mkdir",
[SYS_close]  "close",
[SYS_trace]  "trace",
};
```

**c) `kernel/syscall.c`**: sửa hàm `syscall()`. Thêm hai dòng `if` và `printf` **ngay sau** dòng gọi hàm xử lý:
```c
p->trapframe->a0 = syscalls[num]();

if(p->trace_mask & (1 << num))
  printf("syscall %s -> %d\n", syscall_names[num], (int)p->trapframe->a0);
```

**✅ Người 3 phải hiểu được:**
- Vì sao in **sau** khi gọi hàm? Vì lúc đó mới có giá trị trả về.
- Vì sao giá trị trả về nằm ở `a0`? Đó là quy ước của RISC-V; khi quay về user, hàm `trace()` trả về chính giá trị trong a0.
- Phép `trace_mask & (1 << num)` hoạt động thế nào?
- Vì sao ép kiểu `(int)`? `a0` là `uint64`, nên ép về `int` để giá trị lỗi `-1` in ra đúng là `-1`.

**d) Việc khác:** viết Phần 4b của report (in log). Người 3 cũng merge code của cả nhóm (mục 7), tạo patch và zip (mục 9).

---

## 7. Ghép code và test

**Cách ghép:** dùng repo nhóm `HieuLe832/OS_syscall`, nên để **private** để nhóm khác không chép được. Mỗi người làm trên một branch riêng (ví dụ `nguoi1`, `nguoi2`, `nguoi3`), rồi **Người 3 merge vào `main`**. Vì ba người sửa các file khác nhau nên gần như không có conflict. Ghép xong, **Người 1 chạy test**.

Sau khi ghép đủ, build và chạy:
```bash
make qemu
```

Trong QEMU, chạy ba lệnh sau và so với output trong PDF:
```
$ trace 32 grep hello README
$ trace 2147483647 grep hello README
$ grep hello README
```

Kết quả đúng trên repo của nhóm (đã chạy thử):
```
$ trace 32 grep hello README
syscall read -> 1023
syscall read -> 971
syscall read -> 298
syscall read -> 0
$ trace 2147483647 grep hello README
syscall trace -> 0
syscall exec -> 3
syscall open -> 3
syscall read -> 1023
syscall read -> 971
syscall read -> 298
syscall read -> 0
syscall close -> 0
$ grep hello README
$
```
- Lệnh 1 chỉ in các dòng `read`.
- Lệnh 2 in đủ trace, exec, open, read, close.
- Lệnh 3 không in dòng trace nào.
- Số byte `971`, `298` khác PDF (`966`, `70`) là do `README` bản 2024 dài hơn (xem mục 3).

Thử thêm để chắc chắn hiểu bài:
- `trace 65568 grep xv6 README` in cả `read` lẫn `write`. Các dòng `write` xen giữa những dòng grep tìm thấy, vì grep ghi từng dòng ra màn hình bằng `write`. (Đừng dùng `grep hello`: README không có chữ "hello" nên grep không `write` gì.)
- `trace 65536 echo hi` chỉ in các dòng `write`. Dòng log có thể dính liền với chữ `hi`, vì kernel và chương trình cùng in ra một console.
- `trace 2 usertests forkforkfork` in rất nhiều dòng `fork`, chứng tỏ tiến trình con cũng được trace. Lệnh này chạy hơi lâu.

## 8. Lỗi thường gặp

| Triệu chứng | Nguyên nhân thường gặp |
|---|---|
| `undefined reference to 'trace'` khi build | Thiếu `entry("trace")` trong usys.pl hoặc khai báo trong user.h |
| `SYS_trace undeclared` | Chưa thêm `#define SYS_trace 22` vào syscall.h |
| `exec trace failed` hoặc không tìm thấy lệnh trace | Chưa thêm `$U/_trace\` vào Makefile |
| In ra `unknown sys call 22` | Chưa thêm `[SYS_trace] sys_trace` vào mảng `syscalls[]` |
| Chạy được nhưng không in gì | sys_trace chưa lưu mask, hoặc dòng printf đặt **trước** khi gọi hàm |
| In ra tên sai hoặc `(null)` | Thiếu tên trong `syscall_names[]` |
| Build báo `error: unused variable ...` | Makefile có `-Werror`, mọi cảnh báo đều thành lỗi. Xóa biến thừa |
| `make grade` báo FAIL dù output giống PDF | Bình thường. Script của MIT tìm định dạng có PID và chấm cả phần gdb, attack mà đề môn học không yêu cầu |

## 9. Nộp bài (report: cả nhóm, Người 1 ghép; patch, zip: Người 3)

**Tên file nộp:** `MSSV1_MSSV2_MSSV3.zip`, xếp MSSV **tăng dần**.

**Bên trong file zip gồm:**

1. **`MSSV1_MSSV2_MSSV3_Report.pdf`**: đề yêu cầu *"short and sweet"*, tức **ngắn gọn, không dán code**. Khoảng 3–5 trang là đủ. Dàn ý và người viết:

   | Phần | Nội dung | Người viết |
   |---|---|---|
   | 1. Thông tin nhóm | MSSV, họ tên, bảng phân công, mức độ hoàn thành | Người 1 |
   | 2. Tổng quan | Luồng một syscall từ `trace()` qua `ecall`, `syscall()` tới `sys_trace()`; mask là gì. Có thể vẽ lại sơ đồ ở mục 2 | Người 2 |
   | 3. Phía user | `user.h`, `usys.pl`, `Makefile`, số hiệu trong `syscall.h`; cách `trace.c` (có sẵn trong repo MIT, nhóm dùng lại) gọi `exec` | Người 1 |
   | 4a. Lưu mask | `trace_mask` trong `struct proc`, `sys_trace`, copy khi `fork`, reset khi `freeproc` | Người 2 |
   | 4b. In log | Đăng ký vào `syscalls[]`, bảng tên, vị trí và điều kiện in | Người 3 |
   | 5. Kết quả | Ảnh chụp ba lệnh test ở mục 7, giải thích vì sao số byte `read` khác PDF | Người 1 |
   | 6. Khó khăn | Lỗi đã gặp, cách đã thử, chỗ chưa chắc chắn. Phần này giúp được chấm điểm một phần nếu bài chưa hoàn chỉnh | **Mỗi người tự viết phần của mình** |

   Mỗi người viết phần của mình **bằng lời, ở mức ý tưởng**, nộp cho Người 1 ghép. Viết xong phần của mình cũng là một cách ôn vấn đáp.
2. **`MSSV1_MSSV2_MSSV3.patch`**: so với code gốc của MIT (nhánh `origin/original/syscall`, commit `d5b09ff`).
3. **Source xv6**: đã `make clean`, nén thành một file zip.

`Dockerfile` và `docs/` là file riêng của nhóm, **phải loại ra** khỏi patch và zip. Chạy các lệnh sau ở thư mục gốc repo (trong container cũng được, image đã có `zip`):

```bash
make clean
mkdir -p submissions        # thư mục này nằm trong .gitignore, git sẽ bỏ qua

# Patch: gồm cả phần đã commit lẫn chưa commit, trừ Dockerfile và docs/
git add -A
git diff --cached origin/original/syscall -- . ':(exclude)Dockerfile' ':(exclude)docs' \
    > submissions/MSSV1_MSSV2_MSSV3.patch

# Source: bỏ .git, submissions/, Dockerfile, docs/
zip -r submissions/MSSV1_MSSV2_MSSV3_xv6.zip . \
    -x '.git/*' 'submissions/*' 'Dockerfile' 'docs/*'
```

Kiểm tra: `grep '^diff' submissions/MSSV1_MSSV2_MSSV3.patch` chỉ được liệt kê các file bài làm (`Makefile`, `kernel/...`, `user/...`).

Cuối cùng, chép file report PDF vào `submissions/` rồi nén 3 file thành file nộp lên Moodle:

```bash
cd submissions
zip MSSV1_MSSV2_MSSV3.zip MSSV1_MSSV2_MSSV3_Report.pdf MSSV1_MSSV2_MSSV3.patch MSSV1_MSSV2_MSSV3_xv6.zip
```

> Đề ghi bài giống nhau giữa các nhóm sẽ bị 0 điểm toàn bộ phần thực hành. Hãy tự viết và tự hiểu code.

## 10. Chuẩn bị vấn đáp

**Cách luyện:** sau khi xong, mỗi người dành khoảng 10 phút giảng phần của mình cho hai người còn lại. Sau đó mỗi người tự giải thích **toàn bộ luồng** từ `trace(32)` đến lúc in ra dòng log.

| Câu hỏi hay gặp | Ý chính để trả lời |
|---|---|
| System call là gì? | Cách để chương trình user nhờ kernel làm việc cần quyền cao (đọc file, tạo tiến trình…) |
| `ecall` làm gì? | Lệnh RISC-V gây trap, chuyển CPU từ user mode sang kernel mode và nhảy vào code xử lý trap |
| a7 và a0 dùng để làm gì? | a7 chứa số hiệu syscall; a0 đến a5 chứa tham số; a0 chứa giá trị trả về |
| `usys.pl` để làm gì? | Script perl sinh ra `usys.S`, chứa các stub đặt số vào a7 rồi gọi `ecall` |
| `argint` lấy tham số từ đâu? | Từ trapframe của tiến trình, nơi lưu các thanh ghi user lúc trap |
| Vì sao mask lưu trong `struct proc`? | Mỗi tiến trình có struct riêng, nên trace chỉ ảnh hưởng tiến trình gọi nó |
| Vì sao exec không làm mất mask? | exec thay code và bộ nhớ nhưng giữ nguyên tiến trình, tức cùng `struct proc` |
| Vì sao copy mask trong fork? | Để tiến trình con của chương trình được trace cũng được trace |
| Vì sao in log ở `syscall()`? | Mọi syscall đều đi qua đây, và tại đây có cả số hiệu lẫn giá trị trả về |
| Số 32 nghĩa là gì? | 1 << 5, mà 5 là `SYS_read`, nên chỉ theo dõi read |
| Vì sao có dòng `syscall exec -> 3`? | exec trả về argc, ở đây là 3 (grep, hello, README) |
| Vì sao có dòng `syscall trace -> 0`? | Mask được set ngay trong lời gọi trace, nên lúc trace trả về nó đã nằm trong mask |
