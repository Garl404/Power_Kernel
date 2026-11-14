# 内存管理

Power Kernel 的内存管理分两层：**物理内存**和**虚拟内存**。

## 物理内存管理

### buddy 分配器

物理页由 **buddy 分配器**管理（取代了早期的 bitmap）：

| 常量 | 值 | 含义 |
|------|-----|------|
| `BUDDY_BASE` | `0x1000000`（16 MiB） | 可分配物理区起点 |
| `BUDDY_END` | `0x4000000`（64 MiB） | 可分配物理区终点 |
| `BUDDY_MAX_ORDER` | 12 | 最大阶（即 4096 页 = 16 MiB 块） |

- `buddy_alloc(order)` / `buddy_free(page, order)`，支持分裂与合并
- 空闲链表按阶存放块首的**页号**（通过直接映射访问）
- `pmm_alloc()` = `buddy_alloc(0)`（一页），`pmm_free()` = `buddy_free(0)`

### slab 分配器

内核堆的 `kmalloc`/`kfree` 由 **slab** 提供：

- 8 个对象缓存，对象大小 16…2048 字节
- 每个对象前 8 字节存缓存索引，用户指针 = 对象 + 8
- `kfree` 通过 `ptr - 8` 读回索引、归还到对应缓存

## 虚拟内存管理

### 分页

- 4 级页表（PML4 → PDPT → PD → PT），2 MiB 大页
- 页表项标志：`PRESENT(1)` `WRITABLE(2)` `USER(4)`，页掩码 `0x000FFFFFFFFFF000`
- `vmm_p2v(paddr)` = `paddr + DIRECT_MAP_BASE`（物理↔虚拟互转）

### 核心接口

| 函数 | 作用 |
|------|------|
| `vmm_map(pml4, vaddr, paddr, flags)` | 映射一页（自动分配中间页表） |
| `vmm_unmap(pml4, vaddr)` | 取消映射 |
| `vmm_new_space()` | 新建地址空间（复制内核映射，空用户空间） |
| `vmm_switch(cr3)` | 切换地址空间 |
| `vmm_get_pte` | 查询某地址的 PTE |

### 按需分页（demand paging）

页错误处理程序检查 CR2：

- 落在 `LAZY_BASE` 区域（`0x20000000`，`0x3000` 大小）且页不存在 → 分配一页并映射
- 这是"惰性分配"：先给虚拟地址、真正访问时才配物理页

### 写时复制（COW）

- 启动时置 `CR0.WP`（内核态写只读页也会触发 #PF）
- `COW_BASE`（`0x30000000`）区域的只读页被写时 → 分配新页、复制内容、改映射为可写
- 每次改 PTE 后 `invlpg` 使 TLB 失效

### mmap / munmap / mprotect

`MMAP_BASE = 0x40000000` 起，提供用户态内存映射/解映射/改保护的基础原语。

## 内核堆

- 早期 `HEAP_START = 0x400000`、`HEAP_SIZE = 0x800000` 的 bump 堆
- 现已被 slab 取代；`heap_cur` 指针做向后兼容

## 已知问题

- 进程退出时回收了**用户页**，但页表页（PML4/PDPT/PD/PT）仍会泄漏
- `fork` 是整页复制（尚未对 fork 做 COW）
