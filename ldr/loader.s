; vim: set ft=nasm ts=8:
[section .text]

%define LM_NAME_OFFSET           0x4
%define LM_NEXT_OFFSET           0xC
%define LM_ADDR_OFFSET           0
%define LM_INFO_OFFSET           0x20
%define LM_NBUCKETS_OFFSET       0x17c
%define LM_GNU_BUCKETS_OFFSET    0x18c
%define LM_GNU_CHAIN_ZERO_OFFSET 0x190

%define DT_VALUE_OFFSET          0x4
%define DYN_PTR_OFFSET           0x4

%define DT_SYMTAB                0x6
%define DT_SYMSIZE_SHIFT         4


strcmp: ; (const char *s1 (esi), const char *s2 (edi))
       push esi
       push edi
.cmp: lodsb
         or al, al
         jz .done
        sub al, [edi]
        jnz .done
        inc edi
        jmp .cmp
.done:  pop edi
        pop esi
        ret


basename: ; (const char *s (esi))
       push esi
       push edi
        mov edi, esi
.cmp: lodsb
         or al, al
         jz .done
        cmp al, 47 ; '/'
      cmove edi, esi
        jmp .cmp
.done:  mov eax, edi
        pop edi
        pop esi
        ret


link_symbol: ; (struct link_map *entry, uint32_t *h)
        mov ecx, esi

            ; eax = *h % entry->l_nbuckets
        mov eax, [ecx]
        xor edx, edx
        mov ebx, [ebp + LM_NBUCKETS_OFFSET]
        div ebx
            ; eax = entry->l_gnu_buckets[eax]
        mov eax, [ebp + LM_GNU_BUCKETS_OFFSET]
        mov eax, [eax + edx * 4]
            ; *h |= 1
         or word [ecx], 1
.check_bucket:      ; edx = entry->l_gnu_chain_zero[eax] | 1
                mov edx, [ebp + LM_GNU_CHAIN_ZERO_OFFSET]
                mov edx, [edx + eax * 4]
                 or edx, 1
                    ; check if this is our symbol
                cmp edx, [ecx]
                 je .found
                inc eax
                jmp .check_bucket
.found:     ; it is! edx = entry->l_info[DT_SYMTAB]->d_un.d_ptr
        mov edx, [ebp + LM_INFO_OFFSET + DT_SYMTAB * 4]
        mov edx, [edx + DYN_PTR_OFFSET]
            ; edx = edx[eax].dt_value + entry->l_addr
        shl eax, DT_SYMSIZE_SHIFT
        mov edx, [edx + eax + DT_VALUE_OFFSET]
        add edx, [ebp + LM_ADDR_OFFSET]
        sub edx, ecx
        sub edx, 4
            ; finally, write it back!
        mov [ecx], edx
        ret


link: ; (struct link_map *root, char *symtable)
        mov eax, [esp+4]
        mov esi, [esp+8]
.do_library:          ; null library name means end of symbol table, we're done
                  cmp byte [esi], 0
                   jz .done
                      ; setup start of map again
                  mov ebp, eax
                 push eax
.find_map_entry:            ; compare basename(entry->l_name) to lib name, if so we got a match
                       push esi
                        mov esi, [ebp + LM_NAME_OFFSET]
                       call basename
                        mov edi, eax
                        pop esi
                       call strcmp
                         jz .process_map_entry
                            ; no match, next entry it is!
                        mov ebp, [ebp + LM_NEXT_OFFSET]
                        jmp .find_map_entry
.process_map_entry:         ; skip past the name in the symbol table now to get to the symbols
                      lodsb
                         or al, al
                        jnz .process_map_entry

.do_symbols:                ; null byte means end of symbols for this library!
                        cmp byte [esi], 0
                         jz .next_library
                        inc esi
                       call link_symbol
                        add esi, 4
                        jmp .do_symbols
.next_library:  pop eax
                inc esi
                jmp .do_library
.done:  ret


extern main
_start:
       push _symbols
       push eax
       call link

       call main
       int3

