;; ==**  ~        +=+   +
;;   =+ :~ :=+++ + =  =:
;;    == =    ++ + ~ ~~
;;     ==:~   ,= +  =
;;      = =    = += ~
;;      ~==    ~=+,=
;;       = ~    ?+=
;;        +~  =??+
;;        += =/ ++
;;        +?+~  ++
;;        ~+   =+
;;
;; This code is released into the public domain.
;; The authors disclaim all effects of latent XM expose.
;; Original copyright string: (C) 1992 VITRONICS, Inc.
;; qemu-system-x86_64 -cpu 'Skylake-Server' -drive format=raw,file=viOS.bin

;%define KILL_PROC
%define PAGE_PRESENT (1 << 0)
%define PAGE_WRITE (1 << 1)
%define PML4T_ADDR 0x1000

[ORG 0x7c00]
[BITS 16]
main16:
    ; set up segments
    cli
    xor ax, ax
    mov ss, ax
    mov sp, main16 ; put the stack just below the code

    ; no room for any of this...
    ;mov ds, ax
    ;mov es, ax
    ;mov fs, ax
    ;mov gs, ax

    ; print banner
    call clear
    mov si, logo
    call print_logo
    mov si, z_boot_msg
    call print
%ifdef KILL_PROC
    call die
%endif

    jmp go_long_mode

; Tries to get into long mode (from real mode) as quickly as possible.
; will break on a 486 but will work in 2018 :-)
go_long_mode:
    ; clear out the page tables (0x1000 dwords)
    mov edi, PML4T_ADDR
    mov cr3, edi
    mov ecx, 0x1000
    xor eax, eax
    cld
    rep stosd
    mov edi, cr3

    ; set up the intermediate page table levels
    mov dword [edi], 0x2000 | PAGE_PRESENT | PAGE_WRITE ; PML4T
    lea edi, [edi + 0x1000]
    mov dword [edi], 0x3000 | PAGE_PRESENT | PAGE_WRITE ; PDPT
    lea edi, [edi + 0x1000]
    mov dword [edi], 0x4000 | PAGE_PRESENT | PAGE_WRITE ; PDT
    lea edi, [edi + 0x1000]

    ; create 256 pages (1MB), identity mapped
    mov ebx, 0x3  ; rw
    mov ecx, 256
.set_pte:
    mov dword [edi], ebx
    add ebx, 0x1000
    add edi, 8
    loop .set_pte

    ; disable IRQs
    ;mov al, 0xff
    ;out 0xa1, al
    ;out 0x21, al

    ; load an empty interrupt discriptor table
    ;lidt [IDT]

    ; enable the a20 gate so we can address more than 20 bits of memory
    ;mov al, 2
    ;out 0x92, al

    ; enable SSE etc. don't need all this.
    ; need OSXSAVE even though it makes Bochs die. QEMU seems support it.
    ; hard mode: they can try on a real PC and post to G+ for high-value code
    ; bonus points for using a floppy disk
    mov eax, 0x000406a3 ; OSXSAVE | OSXMMEXCPT | OSFSXR | PAE | PVI :-) | VME
    mov cr4, eax

    ; enable long mode support
    mov ecx, 0xc0000080 ; EFER (extended feature enable)
    rdmsr
    or eax, 0x100 ; long mode
    wrmsr

    ; if we're here, we're about to enable protected mode, so display a message
    mov si, z_long_msg
    call print
%ifdef KILL_PROC
    call die
%endif

    ; if they can't execute AVX instructions, the processor will die after
    ; printing "goo.gl/" so give them a little hint for what it was about to do
    mov si, z_googl
    call print

    ; protected mode time, none of our BIS fns will work after this
    mov eax, cr0
    and eax, 0xfffffffb ; clear coproc emulation
    or eax, 0x80010003  ; Paging, write protect, monitor coproc, protected mode
    mov cr0, eax        ; we still alive?

    ; load the long mode GDT and jump into long mode
    lgdt [GDT64.pointer]
    jmp GDT64.code:main64

; Load si with the address of the logo; this will print it
print_logo:
    pushad
    mov cx, 11 ; rows
.print_logo_loop:
    call print_logo_row
    push si
    mov si, z_crlf
    call print
    pop si
    add si, 3
    loop .print_logo_loop
.print_logo_out:
    popad
    ret

; Kills the CPU
; sensitive can patch by removing callcites with nop or changing hlt into ret
die:
    mov si, z_halted
    call print
    hlt

; Load si with the address of the row, and this function will unpack and print
print_logo_row:
    pushad

    ; this will load upper 8 bits with garbage but we only care about 24/32
    mov ebx, dword [si]
    cld
    mov cx, 24      ; bits per row
.print_logo_row_loop:
    bt ebx, 0       ; is low bit 1?
    setc al         ; sets al to i if the low bit is 1
    imul ax, ax, 42 ; multiply by 42 (produce asterisk or NUL)
    or al, 0x20     ; convert NUL to space
    mov ah, 0x0e
    int 0x10        ; print it
    shr ebx, 1
    loop .print_logo_row_loop
.print_logo_row_out:
    popad
    ret

; Load si with the address of text, and this will print it
; pulled straight from earlier '90s source archives
print:
    pushad
.print_loop:
    lodsb
    test al, al
    je .print_done
    mov ah, 0x0e
    int 0x10
    jmp .print_loop
.print_done:
    popad
    ret

; Clears the screen.
clear:
    xor ah, ah
    mov al, 0x03
    int 0x10
    ret

; all 64 bit code from now on

%include "vios/main64.asm"

; place all the data at the end
ALIGN 1
logo: ; vi logo bitmap
      ; same one on g+ but simpler (original would take up half the bootsector)
    db 0x9e, 0x00, 0x47
    db 0xd8, 0xbe, 0x32
    db 0xb0, 0xb0, 0x1a
    db 0xe0, 0xb1, 0x04
    db 0x40, 0xa1, 0x05
    db 0xc0, 0xe1, 0x03
    db 0x80, 0xc2, 0x01
    db 0x00, 0xf3, 0x00
    db 0x00, 0xdb, 0x00
    db 0x00, 0xcf, 0x00
    db 0x00, 0x63, 0x00

; null-terminated strings; mostly preserved from the original
; added goo.gl string for 20185 version given to sensitives
z_boot_msg: db 0x0d, 0x0a, "VI.OS v0.5.1798", 0x0d, 0x0a, \
            "(C) '92 VITRONICS", 0x0d, 0x0a, 0
z_halted: db "SYS_HALTED", 0
z_long_msg: db "Booting", 0x0d, 0x0a, 0
z_googl: db 1, " goo.gl/"
z_crlf: db 0x0d, 0x0a, 0

;ALIGN 4
;IDT:
;    .length dw 0
;    .base   dd 0

; this is new
ALIGN 8
GDT64:
.null: equ $ - GDT64
    dw 0x0000    ; limit
    dw 0x0000    ; base (low)
    db 0x00      ; base (middle)
    db 0x00      ; access (none)
    db 0x00      ; flags
    db 0x00      ; base (high)
.code: equ $ - GDT64
    dw 0x0000    ; limit
    dw 0x0000    ; base (low)
    db 0x00      ; base (middle)
    db 10011010b ; access (present/exec/read)
    db 00100000b ; 64 bit
    db 0x00      ; base (high)
    dw 0         ; pad
.data: equ $ - GDT64
    dw 0x0000    ; limit
    dw 0x0000    ; base (low)
    db 0x00      ; base (middle)
    db 10010010b ; access (read/write)
    db 00100000b ; 64 bit
    db 0x00      ; base (high)
.pointer:
    dw $ - GDT64 - 1 ; size of GDT
    dq GDT64         ; base addr

; zero fill to 512 bytes
times 510 - ($-$$) db 0
dw 0xaa55