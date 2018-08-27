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

; uncomment to test the shuffling while debugging AVX
;%define TEST

[BITS 64]
main64:
    ; turn on AVX support
	xor rcx, rcx
    xgetbv
    or eax, 0x07 ; set more bits (0xb7) if we use AVX-512
    xsetbv

%ifdef TEST
    ; just use existing value
    vmovdqu xmm0, [out]
%else
    ; deobfuscate it
    vmovdqu xmm0, [in01]
    vmpsadbw xmm0, xmm0, [in02], 0
    
    ; would be harder, no support in modern emulators
    ; also needs a newer version of nasm to assemble
    ;vpdpbusd xmm0, xmm1, [in02]
%endif
    ; turn the result into something that's printable
    vpshufb xmm0, xmm0, [shuf]

    ; write it. massive hack to use a hardcoded addr here,
    ; but this is where it lands after "goo.gl/" and there's not much room
    ; in this boot sector left.
    ;
    ; text RAM starts at 0xb8000 - all mmio from here on out
    vmovdqu [0xb8000+2400+18], xmm0

    ; winner winner
    hlt

; generating these is left as an exercise to the reader
ALIGN 1
%ifdef TEST
out: db 0x63, 0x00, 0x6e, 0x00, 0x67, 0x00, 0x63, 0x00, 0x72, 0x00, 0x63, \
        0x00, 0x06, 0x00, 0x07, 0x00
%else
in01: db 0x12, 0x58, 0x0c, 0x06, 0x1f, 0x59, 0x06, 0x0b, 0x10, 0x12, 0x11
in02: db 0x06, 0x10, 0x10, 0x11
%endif
shuf: db 0x00, 0x0e, 0x02, 0x0e, 0x04, 0x0e, 0x06, 0x0e, 0x08, 0x0e, 0x0a, \
         0x0e, 0x80, 0x80, 0x80, 0x80