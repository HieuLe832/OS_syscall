# Môi trường build & chạy xv6 (MIT 6.1810 – xv6-labs-2024, nhánh syscall, RISC-V) cho Lab 0
# Gói cài đặt lấy đúng theo Setup-lab.pdf (mục Ubuntu 24).
# Đã thử: build + boot xv6 và chạy trace thành công với bộ công cụ này.
#   riscv64-linux-gnu-gcc 13.3 | binutils 2.42 | QEMU 8.2.2 | gdb-multiarch 15.1
#   (Setup-lab.pdf yêu cầu tối thiểu QEMU 7.2, GDB 8.3)
#
# Build image (đứng ở thư mục gốc repo): docker build -t xv6-env .
# Chạy container                       : xem docs/DAC_TA_PHIEN_BAN.md, mục 6

# Ghim Ubuntu 24.04 để cả nhóm dùng CÙNG một compiler (GCC 13)
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        gcc-riscv64-linux-gnu \
        binutils-riscv64-linux-gnu \
        qemu-system-misc \
        gdb-multiarch \
        git \
        perl \
        python3 \
        zip \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# perl   : Makefile chạy user/usys.pl để sinh user/usys.S
# python3: các script chấm điểm (grade-lab-*) của MIT
# zip    : đóng gói bài nộp (docs/Huong_dan_Lab0_trace.md, mục 9)

# Cho phép git làm việc với thư mục mount từ máy thật (khác chủ sở hữu)
RUN git config --system --add safe.directory '*'

# Mã nguồn xv6 sẽ được mount vào đây khi chạy container
WORKDIR /xv6

CMD ["bash"]
