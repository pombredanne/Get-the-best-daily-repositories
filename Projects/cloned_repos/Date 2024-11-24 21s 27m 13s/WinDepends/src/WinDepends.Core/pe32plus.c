/*
*  File: pe32plus.c
*
*  Created on: Jul 11, 2024
*
*  Modified on: Nov 15, 2024
*
*      Project: WinDepends.Core
*
*      Author:
*/

#include "core.h"
#include "pe32plus.h"
#include "vsverinfo.h"

DWORD PAGE_ALIGN(DWORD p)
{
    DWORD r = p % PAGE_SIZE;
    if (r == 0)
        return p;

    return p + PAGE_SIZE - r;
}

DWORD ALIGN_UP(DWORD p, DWORD a)
{
    DWORD r = p % a;
    if (r == 0)
        return p;

    return p + a - r;
}

DWORD ALIGN_DOWN(DWORD p, DWORD a)
{
    return p - (p % a);
}

BOOL relocimage64(
    _In_ LPVOID MappedView,
    _In_ LPVOID RebaseFrom,
    _In_ PIMAGE_BASE_RELOCATION RelData,
    _In_ ULONG RelDataSize)
{
    LPWORD      entry;
    LONG64      delta = (ULONG_PTR)MappedView - (ULONG_PTR)RebaseFrom;
    PIMAGE_BASE_RELOCATION next_block, RelData0 = RelData;
    ULONG       p = 0, block_size;
    LONG64      rel, *ptr;

    if (RelDataSize < sizeof(IMAGE_BASE_RELOCATION))
        return FALSE;

    /* validate */
    while (p < RelDataSize)
    {
        block_size = RelData->SizeOfBlock;
        if ((block_size < sizeof(IMAGE_BASE_RELOCATION)) ||
            (p + block_size > RelDataSize) ||
            (block_size % sizeof(WORD) != 0))
        {
            return FALSE;
        }

        next_block = (PIMAGE_BASE_RELOCATION)((LPBYTE)RelData + block_size);
        for (entry = (LPWORD)(RelData + 1); entry < (LPWORD)next_block; ++entry)
        {
            switch (*entry >> 12)
            {
            case IMAGE_REL_BASED_HIGHLOW:
            case IMAGE_REL_BASED_DIR64:
            case IMAGE_REL_BASED_ABSOLUTE:
                break;
            default:
                /* unsupported reloc found */
                return FALSE;
                break;
            }
        }
        p += block_size;
        RelData = next_block;
    }

    if (p != RelDataSize)
        return FALSE;

    /* do relocate */
    p = 0;
    RelData = RelData0;
    while (p < RelDataSize)
    {
        block_size = RelData->SizeOfBlock;
        next_block = (PIMAGE_BASE_RELOCATION)((LPBYTE)RelData + block_size);
        for (entry = (LPWORD)(RelData + 1); entry < (LPWORD)next_block; ++entry)
        {
            switch (*entry >> 12)
            {
            case IMAGE_REL_BASED_HIGHLOW:
                ptr = (LONG64*)((LPBYTE)MappedView + RelData->VirtualAddress + (*entry & 0x0fff));
                rel = *(PULONG)ptr; // need zero extend value here (movzx)
                rel += delta;
                *(PLONG)ptr = (LONG)rel;
                break;
            case IMAGE_REL_BASED_DIR64:
                ptr = (LONG64*)((LPBYTE)MappedView + RelData->VirtualAddress + (*entry & 0x0fff));
                rel = *ptr;
                rel += delta;
                *ptr = rel;
                break;
            case IMAGE_REL_BASED_ABSOLUTE:
                // no relocation needed
                break;
            default:
                /* unsupported reloc found */
                return FALSE;
                break;
            }
        }
        p += block_size;
        RelData = next_block;
    }

    return TRUE;
}

LPVOID get_manifest(
    _In_ HMODULE module
)
{
    HRSRC   h_manifest;
    DWORD   sz_manifest, cch_encoded = 0;
    HGLOBAL p_manifest;
    LPVOID  encoded;

    do {
        h_manifest = FindResource(module, CREATEPROCESS_MANIFEST_RESOURCE_ID, RT_MANIFEST);
        if (h_manifest == NULL)
            break;

        sz_manifest = SizeofResource(module, h_manifest);
        if (sz_manifest == 0)
            break;

        p_manifest = LoadResource(module, h_manifest);
        if (p_manifest == NULL)
            break;

        if (CryptBinaryToString(p_manifest, sz_manifest, CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF, NULL, &cch_encoded))
        {
            encoded = heap_calloc(NULL, cch_encoded * sizeof(WCHAR));
            if (encoded)
            {
                if (CryptBinaryToString(p_manifest, sz_manifest, CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF, encoded, &cch_encoded))
                    return encoded;
                else
                    heap_free(NULL, encoded);
            }
        }

    } while (FALSE);

    return NULL;
}

BOOL get_datadirs(
    _In_ SOCKET s,
    _In_ pmodule_ctx context
)
{
    LIST_ENTRY          msg_lh;
    PIMAGE_DOS_HEADER   dos_hdr = (PIMAGE_DOS_HEADER)context->module;
    PIMAGE_FILE_HEADER  nt_file_hdr;
    BOOL                status = FALSE;
    WCHAR               text[1024];
    DWORD               dir_limit, c;

    define_3264_union(IMAGE_OPTIONAL_HEADER, opt_file_hdr);


    if (!context->module)
    {
        sendstring_plaintext(s, WDEP_STATUS_404);
        return FALSE;
    }

    __try {

        InitializeListHead(&msg_lh);

        nt_file_hdr = (PIMAGE_FILE_HEADER)(context->module + sizeof(DWORD) + dos_hdr->e_lfanew);
        opt_file_hdr.opt_file_hdr32 = (IMAGE_OPTIONAL_HEADER32*)((PBYTE)nt_file_hdr + sizeof(IMAGE_FILE_HEADER));

        mlist_add(&msg_lh, WDEP_STATUS_OK "{\"directories\":[");

        switch (opt_file_hdr.opt_file_hdr32->Magic)
        {
        case IMAGE_NT_OPTIONAL_HDR32_MAGIC:

            if (opt_file_hdr.opt_file_hdr32->NumberOfRvaAndSizes > 256)
                dir_limit = 256;
            else
                dir_limit = opt_file_hdr.opt_file_hdr32->NumberOfRvaAndSizes;

            for (c = 0; c < dir_limit; ++c)
            {
                if (c > 0)
                    mlist_add(&msg_lh, L",");

                StringCchPrintf(text, ARRAYSIZE(text),
                    L"{\"vaddress\":%u,\"size\":%u}",
                    opt_file_hdr.opt_file_hdr32->DataDirectory[c].VirtualAddress,
                    opt_file_hdr.opt_file_hdr32->DataDirectory[c].Size
                );

                mlist_add(&msg_lh, text);
            }
            break;

        case IMAGE_NT_OPTIONAL_HDR64_MAGIC:

            if (opt_file_hdr.opt_file_hdr64->NumberOfRvaAndSizes > 256)
                dir_limit = 256;
            else
                dir_limit = opt_file_hdr.opt_file_hdr64->NumberOfRvaAndSizes;

            for (c = 0; c < dir_limit; ++c)
            {
                if (c > 0)
                    mlist_add(&msg_lh, L",");

                StringCchPrintf(text, ARRAYSIZE(text),
                    L"{\"vaddress\":%u,\"size\":%u}",
                    opt_file_hdr.opt_file_hdr64->DataDirectory[c].VirtualAddress,
                    opt_file_hdr.opt_file_hdr64->DataDirectory[c].Size
                );
                
                mlist_add(&msg_lh, text);
            }

            break;
        }

        mlist_add(&msg_lh, L"]}\r\n");
        mlist_traverse(&msg_lh, mlist_send, s);
    }
    __except (ex_filter_dbg(context->filename, GetExceptionCode(), GetExceptionInformation()))
    {
        printf("exception in get_datadirs\r\n");
        mlist_traverse(&msg_lh, mlist_free, s);
        sendstring_plaintext(s, WDEP_STATUS_600);
    }

    return status;
}

BOOL get_headers(
    _In_ SOCKET s,
    _In_ pmodule_ctx context
)
{
    LIST_ENTRY          msg_lh;
    PIMAGE_DOS_HEADER   dos_hdr = (PIMAGE_DOS_HEADER)context->module;
    PIMAGE_FILE_HEADER  nt_file_hdr;
    BOOL                status = FALSE;
    WCHAR               *text = NULL, *manifest = NULL;
    ULONG               textsize = 16384, i;
    DWORD               dir_base = 0, dir_size = 0, dllchars_ex = 0, image_size = 0;

    PIMAGE_DEBUG_DIRECTORY  pdbg = NULL;

    define_3264_union(IMAGE_OPTIONAL_HEADER, opt_file_hdr);

    if (!context->module)
    {
        sendstring_plaintext(s, WDEP_STATUS_404);
        return FALSE;
    }

    __try
    {
        text = VirtualAllocEx(GetCurrentProcess(), 
            NULL, 
            textsize * sizeof(WCHAR), 
            MEM_RESERVE | MEM_COMMIT, 
            PAGE_READWRITE);

        if (!text)
        {
            sendstring_plaintext(s, WDEP_STATUS_500);
            __leave;
        }

        InitializeListHead(&msg_lh);

        nt_file_hdr = (PIMAGE_FILE_HEADER)(context->module + sizeof(DWORD) + dos_hdr->e_lfanew);
        opt_file_hdr.opt_file_hdr32 = (IMAGE_OPTIONAL_HEADER32*)((PBYTE)nt_file_hdr + sizeof(IMAGE_FILE_HEADER));
        mlist_add(&msg_lh, WDEP_STATUS_OK L"{\"headers\":");

        StringCchPrintf(text, textsize,
            L"{\"ImageFileHeader\":{"
            L"\"Machine\":%u,"
            L"\"NumberOfSections\":%u,"
            L"\"TimeDateStamp\":%u,"
            L"\"PointerToSymbolTable\":%u,"
            L"\"NumberOfSymbols\":%u,"
            L"\"SizeOfOptionalHeader\":%u,"
            L"\"Characteristics\":%u},",
            nt_file_hdr->Machine,
            nt_file_hdr->NumberOfSections,
            nt_file_hdr->TimeDateStamp,
            nt_file_hdr->PointerToSymbolTable,
            nt_file_hdr->NumberOfSymbols,
            nt_file_hdr->SizeOfOptionalHeader,
            nt_file_hdr->Characteristics
        );

        mlist_add(&msg_lh, text);

        switch (opt_file_hdr.opt_file_hdr32->Magic)
        {
        case IMAGE_NT_OPTIONAL_HDR32_MAGIC:
            image_size = opt_file_hdr.opt_file_hdr32->SizeOfImage;

            get_pe_dirbase_size(opt_file_hdr.opt_file_hdr32, IMAGE_DIRECTORY_ENTRY_DEBUG, dir_base, dir_size);

            StringCchPrintf(text, textsize,
                L"\"ImageOptionalHeader\":{"
                L"\"Magic\":%u,"
                L"\"MajorLinkerVersion\":%u,"
                L"\"MinorLinkerVersion\":%u,"
                L"\"SizeOfCode\":%u,"
                L"\"SizeOfInitializedData\":%u,"
                L"\"SizeOfUninitializedData\":%u,"
                L"\"AddressOfEntryPoint\":%u,"
                L"\"BaseOfCode\":%u,"
                L"\"BaseOfData\":%u,"
                L"\"ImageBase\":%u,"
                L"\"SectionAlignment\":%u,"
                L"\"FileAlignment\":%u,"
                L"\"MajorOperatingSystemVersion\":%u,"
                L"\"MinorOperatingSystemVersion\":%u,"
                L"\"MajorImageVersion\":%u,"
                L"\"MinorImageVersion\":%u,"
                L"\"MajorSubsystemVersion\":%u,"
                L"\"MinorSubsystemVersion\":%u,"
                L"\"Win32VersionValue\":%u,"
                L"\"SizeOfImage\":%u,"
                L"\"SizeOfHeaders\":%u,"
                L"\"CheckSum\":%u,"
                L"\"Subsystem\":%u,"
                L"\"DllCharacteristics\":%u,"
                L"\"SizeOfStackReserve\":%u,"
                L"\"SizeOfStackCommit\":%u,"
                L"\"SizeOfHeapReserve\":%u,"
                L"\"SizeOfHeapCommit\":%u,"
                L"\"LoaderFlags\":%u,"
                L"\"NumberOfRvaAndSizes\":%u}",
                opt_file_hdr.opt_file_hdr32->Magic,
                opt_file_hdr.opt_file_hdr32->MajorLinkerVersion,
                opt_file_hdr.opt_file_hdr32->MinorLinkerVersion,
                opt_file_hdr.opt_file_hdr32->SizeOfCode,
                opt_file_hdr.opt_file_hdr32->SizeOfInitializedData,
                opt_file_hdr.opt_file_hdr32->SizeOfUninitializedData,
                opt_file_hdr.opt_file_hdr32->AddressOfEntryPoint,
                opt_file_hdr.opt_file_hdr32->BaseOfCode,
                opt_file_hdr.opt_file_hdr32->BaseOfData,
                opt_file_hdr.opt_file_hdr32->ImageBase,
                opt_file_hdr.opt_file_hdr32->SectionAlignment,
                opt_file_hdr.opt_file_hdr32->FileAlignment,
                opt_file_hdr.opt_file_hdr32->MajorOperatingSystemVersion,
                opt_file_hdr.opt_file_hdr32->MinorOperatingSystemVersion,
                opt_file_hdr.opt_file_hdr32->MajorImageVersion,
                opt_file_hdr.opt_file_hdr32->MinorImageVersion,
                opt_file_hdr.opt_file_hdr32->MajorSubsystemVersion,
                opt_file_hdr.opt_file_hdr32->MinorSubsystemVersion,
                opt_file_hdr.opt_file_hdr32->Win32VersionValue,
                opt_file_hdr.opt_file_hdr32->SizeOfImage,
                opt_file_hdr.opt_file_hdr32->SizeOfHeaders,
                opt_file_hdr.opt_file_hdr32->CheckSum,
                opt_file_hdr.opt_file_hdr32->Subsystem,
                opt_file_hdr.opt_file_hdr32->DllCharacteristics,
                opt_file_hdr.opt_file_hdr32->SizeOfStackReserve,
                opt_file_hdr.opt_file_hdr32->SizeOfStackCommit,
                opt_file_hdr.opt_file_hdr32->SizeOfHeapReserve,
                opt_file_hdr.opt_file_hdr32->SizeOfHeapCommit,
                opt_file_hdr.opt_file_hdr32->LoaderFlags,
                opt_file_hdr.opt_file_hdr32->NumberOfRvaAndSizes
            );
            
            mlist_add(&msg_lh, text);
            break;

        case IMAGE_NT_OPTIONAL_HDR64_MAGIC:
            image_size = opt_file_hdr.opt_file_hdr64->SizeOfImage;

            get_pe_dirbase_size(opt_file_hdr.opt_file_hdr64, IMAGE_DIRECTORY_ENTRY_DEBUG, dir_base, dir_size);

            StringCchPrintf(text, textsize,
                L"\"ImageOptionalHeader\":{"
                L"\"Magic\":%u,"
                L"\"MajorLinkerVersion\":%u,"
                L"\"MinorLinkerVersion\":%u,"
                L"\"SizeOfCode\":%u,"
                L"\"SizeOfInitializedData\":%u,"
                L"\"SizeOfUninitializedData\":%u,"
                L"\"AddressOfEntryPoint\":%u,"
                L"\"BaseOfCode\":%u,"
                L"\"ImageBase\":%llu,"
                L"\"SectionAlignment\":%u,"
                L"\"FileAlignment\":%u,"
                L"\"MajorOperatingSystemVersion\":%u,"
                L"\"MinorOperatingSystemVersion\":%u,"
                L"\"MajorImageVersion\":%u,"
                L"\"MinorImageVersion\":%u,"
                L"\"MajorSubsystemVersion\":%u,"
                L"\"MinorSubsystemVersion\":%u,"
                L"\"Win32VersionValue\":%u,"
                L"\"SizeOfImage\":%u,"
                L"\"SizeOfHeaders\":%u,"
                L"\"CheckSum\":%u,"
                L"\"Subsystem\":%u,"
                L"\"DllCharacteristics\":%u,"
                L"\"SizeOfStackReserve\":%llu,"
                L"\"SizeOfStackCommit\":%llu,"
                L"\"SizeOfHeapReserve\":%llu,"
                L"\"SizeOfHeapCommit\":%llu,"
                L"\"LoaderFlags\":%u,"
                L"\"NumberOfRvaAndSizes\":%u}",
                opt_file_hdr.opt_file_hdr64->Magic,
                opt_file_hdr.opt_file_hdr64->MajorLinkerVersion,
                opt_file_hdr.opt_file_hdr64->MinorLinkerVersion,
                opt_file_hdr.opt_file_hdr64->SizeOfCode,
                opt_file_hdr.opt_file_hdr64->SizeOfInitializedData,
                opt_file_hdr.opt_file_hdr64->SizeOfUninitializedData,
                opt_file_hdr.opt_file_hdr64->AddressOfEntryPoint,
                opt_file_hdr.opt_file_hdr64->BaseOfCode,
                opt_file_hdr.opt_file_hdr64->ImageBase,
                opt_file_hdr.opt_file_hdr64->SectionAlignment,
                opt_file_hdr.opt_file_hdr64->FileAlignment,
                opt_file_hdr.opt_file_hdr64->MajorOperatingSystemVersion,
                opt_file_hdr.opt_file_hdr64->MinorOperatingSystemVersion,
                opt_file_hdr.opt_file_hdr64->MajorImageVersion,
                opt_file_hdr.opt_file_hdr64->MinorImageVersion,
                opt_file_hdr.opt_file_hdr64->MajorSubsystemVersion,
                opt_file_hdr.opt_file_hdr64->MinorSubsystemVersion,
                opt_file_hdr.opt_file_hdr64->Win32VersionValue,
                opt_file_hdr.opt_file_hdr64->SizeOfImage,
                opt_file_hdr.opt_file_hdr64->SizeOfHeaders,
                opt_file_hdr.opt_file_hdr64->CheckSum,
                opt_file_hdr.opt_file_hdr64->Subsystem,
                opt_file_hdr.opt_file_hdr64->DllCharacteristics,
                opt_file_hdr.opt_file_hdr64->SizeOfStackReserve,
                opt_file_hdr.opt_file_hdr64->SizeOfStackCommit,
                opt_file_hdr.opt_file_hdr64->SizeOfHeapReserve,
                opt_file_hdr.opt_file_hdr64->SizeOfHeapCommit,
                opt_file_hdr.opt_file_hdr64->LoaderFlags,
                opt_file_hdr.opt_file_hdr64->NumberOfRvaAndSizes
            );
            mlist_add(&msg_lh, text);
            break;

        default:
            __leave;
            break;
        }

        pdbg = (PIMAGE_DEBUG_DIRECTORY)(context->module + dir_base);
        if (valid_image_range((ULONG_PTR)pdbg, sizeof(IMAGE_DEBUG_DIRECTORY), (ULONG_PTR)context->module, image_size))
        {
            mlist_add(&msg_lh, L",\"DebugDirectory\":[");

            for (i = 0; dir_size >= sizeof(IMAGE_DEBUG_DIRECTORY); dir_size -= sizeof(IMAGE_DEBUG_DIRECTORY), ++pdbg, i++)
            {
                if ((pdbg->Type == IMAGE_DEBUG_TYPE_EX_DLLCHARACTERISTICS) && (pdbg->AddressOfRawData < image_size - sizeof(DWORD)) && dllchars_ex == 0)
                {
                    dllchars_ex = *(PDWORD)(context->module + pdbg->AddressOfRawData);
                }

                if (i > 0)
                    mlist_add(&msg_lh, L",");

                StringCchPrintf(text, textsize,
                    L"{\"Characteristics\":%u,"
                    L"\"TimeDateStamp\":%u,"
                    L"\"MajorVersion\":%u,"
                    L"\"MinorVersion\":%u,"
                    L"\"Type\":%u,"
                    L"\"SizeOfData\":%u,"
                    L"\"AddressOfRawData\":%u,"
                    L"\"PointerToRawData\":%u}",
                    pdbg->Characteristics,
                    pdbg->TimeDateStamp,
                    pdbg->MajorVersion,
                    pdbg->MinorVersion,
                    pdbg->Type,
                    pdbg->SizeOfData,
                    pdbg->AddressOfRawData,
                    pdbg->PointerToRawData
                );
                
                mlist_add(&msg_lh, text);
            }
        }

        mlist_add(&msg_lh, L"]");

        VS_FIXEDFILEINFO* vinfo;
        vinfo = PEImageEnumVersionFields((HMODULE)context->module, NULL, NULL, (LPVOID)&text);
        if (vinfo)
        {
            StringCchPrintf(text, textsize,
                L",\"Version\":{"
                L"\"dwFileVersionMS\":%u,"
                L"\"dwFileVersionLS\":%u,"
                L"\"dwProductVersionMS\":%u,"
                L"\"dwProductVersionLS\":%u}",
                vinfo->dwFileVersionMS,
                vinfo->dwFileVersionLS,
                vinfo->dwProductVersionMS,
                vinfo->dwProductVersionLS
            );
            
            mlist_add(&msg_lh, text);
        }

        StringCchPrintf(text, textsize,
            L",\"dllcharex\":%u", dllchars_ex);
        
        mlist_add(&msg_lh, text);

        manifest = get_manifest((HMODULE)context->module);
        if (manifest)
        {
            mlist_add(&msg_lh, L",\"manifest\":\"");
            mlist_add(&msg_lh, manifest);
            mlist_add(&msg_lh, L"\"");
            heap_free(NULL, manifest);
        }

        mlist_add(&msg_lh, L"}}\r\n");
        mlist_traverse(&msg_lh, mlist_send, s);
    }
    __except (ex_filter_dbg(context->filename, GetExceptionCode(), GetExceptionInformation()))
    {
        printf("exception in get_headers\r\n");
        mlist_traverse(&msg_lh, mlist_free, s);
        sendstring_plaintext(s, WDEP_STATUS_601);
    }

    if (text != NULL) {
        VirtualFreeEx(GetCurrentProcess(), text, 0, MEM_RELEASE);
    }
    return status;
}

BOOL get_exports(
    _In_ SOCKET s,
    _In_ pmodule_ctx context
)
{
    LIST_ENTRY          msg_lh;
    PIMAGE_DOS_HEADER   dos_hdr = (PIMAGE_DOS_HEADER)context->module;
    PIMAGE_FILE_HEADER  nt_file_hdr;
    DWORD               dir_base = 0, dir_size = 0, i, * ptrs, * names, p, hint, ctr = 0, ImageSize = 0;
    WORD                *name_ordinals;
    BOOL                status = FALSE, names_valid;
    char                *fname, *forwarder;
    WCHAR               text[4096];

    PIMAGE_EXPORT_DIRECTORY ExportTable;

    define_3264_union(IMAGE_OPTIONAL_HEADER, opt_file_hdr);

    if (!context->module)
    {
        sendstring_plaintext(s, WDEP_STATUS_404);
        return FALSE;
    }

    __try
    {
        InitializeListHead(&msg_lh);

        nt_file_hdr = (PIMAGE_FILE_HEADER)(context->module + sizeof(DWORD) + dos_hdr->e_lfanew);
        opt_file_hdr.opt_file_hdr32 = (IMAGE_OPTIONAL_HEADER32*)((PBYTE)nt_file_hdr + sizeof(IMAGE_FILE_HEADER));

        switch (opt_file_hdr.opt_file_hdr32->Magic)
        {
        case IMAGE_NT_OPTIONAL_HDR32_MAGIC:
            ImageSize = opt_file_hdr.opt_file_hdr32->SizeOfImage;
            get_pe_dirbase_size(opt_file_hdr.opt_file_hdr32, IMAGE_DIRECTORY_ENTRY_EXPORT, dir_base, dir_size);
            break;

        case IMAGE_NT_OPTIONAL_HDR64_MAGIC:
            ImageSize = opt_file_hdr.opt_file_hdr64->SizeOfImage;
            get_pe_dirbase_size(opt_file_hdr.opt_file_hdr64, IMAGE_DIRECTORY_ENTRY_EXPORT, dir_base, dir_size);
            break;

        default:
            __leave;
            break;
        }

        if ((dir_base > 0) && (dir_base < ImageSize))
        {
            mlist_add(&msg_lh, WDEP_STATUS_OK L"{\"export\":{");

            ExportTable = (PIMAGE_EXPORT_DIRECTORY)(context->module + dir_base);
            ptrs = (DWORD*)(context->module + ExportTable->AddressOfFunctions);
            names = (DWORD*)(context->module + ExportTable->AddressOfNames);
            name_ordinals = (WORD*)(context->module + ExportTable->AddressOfNameOrdinals);
            
            names_valid = valid_image_range((ULONG_PTR)name_ordinals, ExportTable->NumberOfNames * sizeof(DWORD), (ULONG_PTR)context->module, ImageSize);

            StringCchPrintf(text, ARRAYSIZE(text),
                L"\"library\":{\"timestamp\":%u,\"entries\":%u,\"named\":%u,\"base\":%u,\"functions\":[",
                ExportTable->TimeDateStamp,
                ExportTable->NumberOfFunctions,
                ExportTable->NumberOfNames,
                ExportTable->Base);

            mlist_add(&msg_lh, text);

            for (i = 0; i < ExportTable->NumberOfFunctions; ++i)
            {
                if (!valid_image_range((ULONG_PTR)&ptrs[i], sizeof(DWORD), (ULONG_PTR)context->module, ImageSize))
                    break;

                if (!ptrs[i])
                    continue;

                ++ctr;
                fname = NULL;
                forwarder = "";
                hint = 0;

                if (names_valid)
                {
                    for (p = 0; p < ExportTable->NumberOfNames; ++p)
                    {
                        if (name_ordinals[p] == i)
                        {
                            hint = p;
                            fname = (char*)(context->module + names[p]);
                        }
                    }
                }

                if (fname == NULL)
                {
                    hint = MAXDWORD32;
                    fname = "";
                }

                if ((ptrs[i] >= dir_base) && (ptrs[i] < (dir_base + dir_size)))
                {
                    forwarder = (char*)context->module + ptrs[i];
                }

                if (i > 0)
                    mlist_add(&msg_lh, L",");

                StringCchPrintf(text, ARRAYSIZE(text),
                    L"{\"ordinal\":%u,"
                    L"\"hint\":%u,"
                    L"\"name\":\"%S\","
                    L"\"pointer\":%u,"
                    L"\"forward\":\"%S\"}",
                    ExportTable->Base + i, hint, fname, ptrs[i], forwarder);

                mlist_add(&msg_lh, text);
            }
            mlist_add(&msg_lh, L"]}");
        }
        mlist_add(&msg_lh, L"}}\r\n");
        mlist_traverse(&msg_lh, mlist_send, s);
    }
    __except (ex_filter_dbg(context->filename, GetExceptionCode(), GetExceptionInformation()))
    {
        printf("exception in get_exports\r\n");
        mlist_traverse(&msg_lh, mlist_free, s);
        sendstring_plaintext(s, WDEP_STATUS_603);
    }

    return status;
}

/*
void process_thunks_dbg(PBYTE module, SOCKET s, PIMAGE_THUNK_DATA32 thunk, DWORD64 flag, PULONG32 bound, DWORD_PTR offset)
{
    DWORD   fhint, ordinal;
    char    *strfname;
    ULONG64 fbound = 0;
    WCHAR   text[4096];

    for (; thunk->u1.AddressOfData; ++thunk, ++bound)
    {
        if ((ULONG_PTR)bound > 0x10000) fbound = *bound;
        if ((thunk->u1.Function & flag) != 0)
        {
            strfname = "";
            fhint = MAXDWORD32;
            ordinal = IMAGE_ORDINAL64(thunk->u1.Ordinal);
        }
        else
        {
            PIMAGE_IMPORT_BY_NAME fname;
            if (thunk->u1.Function < offset)
                fname = (PIMAGE_IMPORT_BY_NAME)(module + thunk->u1.Function);
            else
                fname = (PIMAGE_IMPORT_BY_NAME)(module + thunk->u1.Function - offset);
            fhint = fname->Hint;
            strfname = (char*)&fname->Name;
            ordinal = MAXDWORD32;
        }
        
        StringCchPrintf(text, ARRAYSIZE(text),
            L"{\"ordinal\":%u,\"hint\":%u,\"name\":\"%S\",\"bound\":%llu}",
            ordinal, fhint, strfname, fbound);
        sendstring_plaintext(s, text);
    }
}
*/

BOOL get_imports(
    _In_ SOCKET s,
    _In_ pmodule_ctx context
)
{
    LIST_ENTRY                  msg_lh;
    PIMAGE_FILE_HEADER          nt_file_hdr;
    DWORD                       si_dir_base = 0, di_dir_base = 0, dirsize = 0, c;
    DWORD_PTR                   ImageBase = 0, ImageSize = 0, SizeOfHeaders = 0, dnoffset, dioffset;
    BOOL                        status = FALSE, img64 = FALSE, importPresent = FALSE;
    PIMAGE_IMPORT_DESCRIPTOR    SImportTable;
    PIMAGE_DELAYLOAD_DESCRIPTOR DImportTable;
    WCHAR                       text[4096];

    define_3264_union(IMAGE_THUNK_DATA, thunk_data);
    define_3264_union(ULONG, bound_table);
    define_3264_union(IMAGE_OPTIONAL_HEADER, opt_file_header);

    if (!context->module)
    {
        sendstring_plaintext(s, WDEP_STATUS_404);
        return FALSE;
    }  

    __try
    {
        InitializeListHead(&msg_lh);

        nt_file_hdr = (PIMAGE_FILE_HEADER)(context->module + sizeof(DWORD) + ((PIMAGE_DOS_HEADER)context->module)->e_lfanew);
        opt_file_header.uptr = (PBYTE)nt_file_hdr + sizeof(IMAGE_FILE_HEADER);

        switch (opt_file_header.opt_file_header32->Magic)
        {
        case IMAGE_NT_OPTIONAL_HDR32_MAGIC:
            ImageBase = opt_file_header.opt_file_header32->ImageBase;
            ImageSize = opt_file_header.opt_file_header32->SizeOfImage;
            SizeOfHeaders = opt_file_header.opt_file_header32->SizeOfHeaders;
            get_pe_dirbase_size(opt_file_header.opt_file_header32, IMAGE_DIRECTORY_ENTRY_IMPORT, si_dir_base, dirsize);
            get_pe_dirbase_size(opt_file_header.opt_file_header32, IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT, di_dir_base, dirsize);
            break;

        case IMAGE_NT_OPTIONAL_HDR64_MAGIC:
            img64 = TRUE;
            ImageBase = (DWORD_PTR)opt_file_header.opt_file_header64->ImageBase;
            ImageSize = opt_file_header.opt_file_header64->SizeOfImage;
            SizeOfHeaders = opt_file_header.opt_file_header64->SizeOfHeaders;
            get_pe_dirbase_size(opt_file_header.opt_file_header64, IMAGE_DIRECTORY_ENTRY_IMPORT, si_dir_base, dirsize);
            get_pe_dirbase_size(opt_file_header.opt_file_header64, IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT, di_dir_base, dirsize);
            break;

        default:
            __leave;
            break;
        }

        mlist_add(&msg_lh, WDEP_STATUS_OK L"{\"import\":{\"libraries\":[");

        if ((si_dir_base > 0) && (si_dir_base < ImageSize))
        {
            SImportTable = (PIMAGE_IMPORT_DESCRIPTOR)(context->module + si_dir_base);
            for (c = 0; SImportTable->Name && SImportTable->FirstThunk; ++SImportTable, ++c)
            {
                importPresent = TRUE;
                if (c > 0)
                    mlist_add(&msg_lh, L",");

                StringCchPrintf(text, ARRAYSIZE(text), L"{\"name\":\"%S\",\"delay\":0,\"functions\":[", (char*)context->module + SImportTable->Name);
                mlist_add(&msg_lh, text);

                bound_table.uptr = NULL;
                if ((SImportTable->OriginalFirstThunk < SizeOfHeaders) || (SImportTable->OriginalFirstThunk > ImageSize))
                {
                    thunk_data.uptr = context->module + SImportTable->FirstThunk;
                }
                else
                {
                    thunk_data.uptr = context->module + SImportTable->OriginalFirstThunk;
                    if (SImportTable->TimeDateStamp)
                        bound_table.uptr = context->module + SImportTable->FirstThunk;
                }

                if (img64)
                    process_thunks(thunk_data.thunk_data64, IMAGE_ORDINAL_FLAG64, bound_table.bound_table64, 0)
                else
                    process_thunks(thunk_data.thunk_data32, IMAGE_ORDINAL_FLAG32, bound_table.bound_table32, 0);

                mlist_add(&msg_lh, L"]}");
            }
            status = TRUE;           
        }

        if ((di_dir_base > 0) && (di_dir_base < ImageSize))
        {
            DImportTable = (PIMAGE_DELAYLOAD_DESCRIPTOR)(context->module + di_dir_base);

            if (DImportTable->DllNameRVA < ImageBase)
                dioffset = 0;
            else
                dioffset = ImageBase;

            if (DImportTable->ImportNameTableRVA < ImageBase)
                dnoffset = 0;
            else
                dnoffset = ImageBase;

            if (importPresent)
                mlist_add(&msg_lh, L",");

            for (c = 0; DImportTable->DllNameRVA; ++DImportTable, ++c)
            {
                if (c > 0)
                    mlist_add(&msg_lh, L",");

                StringCchPrintf(text, ARRAYSIZE(text), L"{\"name\":\"%S\",\"delay\":1,\"functions\":[", (char*)context->module + DImportTable->DllNameRVA - dioffset);
                mlist_add(&msg_lh, text);

                bound_table.uptr = NULL;
                thunk_data.uptr = context->module + DImportTable->ImportNameTableRVA - dnoffset;
                if (img64)
                    process_thunks(thunk_data.thunk_data64, IMAGE_ORDINAL_FLAG64, bound_table.bound_table64, dnoffset)
                else
                    //process_thunks_dbg(context->module, s, thunk_data.thunk_data32, IMAGE_ORDINAL_FLAG32, bound_table.bound_table32, dnoffset);
                    process_thunks(thunk_data.thunk_data32, IMAGE_ORDINAL_FLAG32, bound_table.bound_table32, dnoffset);

                mlist_add(&msg_lh, L"]}");
            }
            status = TRUE;
        }
        mlist_add(&msg_lh, L"]}}\r\n");
        mlist_traverse(&msg_lh, mlist_send, s);
    }
    __except (ex_filter_dbg(context->filename, GetExceptionCode(), GetExceptionInformation()))
    {
        printf("exception in get_imports\r\n");
        mlist_traverse(&msg_lh, mlist_free, s);
        sendstring_plaintext(s, WDEP_STATUS_602);
    }

    return status;
}

LPBYTE pe32open(
    _In_ SOCKET s,
    _In_ pmodule_ctx context,
    _In_ BOOL fUseReloc,
    _In_ ULONG minAppAddress
)
{
    HANDLE              hf;
    IMAGE_DOS_HEADER    dos_hdr = { 0 };
    IMAGE_FILE_HEADER   nt_file_hdr = { 0 };
    DWORD               iobytes, dwSignature = 0, szOptAndSections,
                        vsize, psize, tsize, status = 0, dwRealChecksum = 0, dir_base = 0, dir_size = 0;
    OVERLAPPED          ovl;
    PBYTE               module = NULL;
    int                 c, startAddress;

    PIMAGE_SECTION_HEADER       sections;
    BY_HANDLE_FILE_INFORMATION  fileinfo = { 0 };
    WCHAR                       text[4096];

    define_3264_union(IMAGE_OPTIONAL_HEADER, opt_file_hdr);

    opt_file_hdr.uptr = NULL;

    hf = CreateFile(context->filename, GENERIC_READ | SYNCHRONIZE, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    if (hf == INVALID_HANDLE_VALUE)
    {
        sendstring_plaintext(s, WDEP_STATUS_404);
        return NULL;
    }

    __try
    {
        if (!GetFileInformationByHandle(hf, &fileinfo))
        {
            sendstring_plaintext(s, WDEP_STATUS_404);
            __leave;
        }

        context->file_size.LowPart = fileinfo.nFileSizeLow;
        context->file_size.HighPart = fileinfo.nFileSizeHigh;

        iobytes = 0;
        if (!ReadFile(hf, &dos_hdr, sizeof(dos_hdr), &iobytes, NULL))
        {
            sendstring_plaintext(s, WDEP_STATUS_403);
            __leave;
        }
        if ((iobytes != sizeof(dos_hdr)) || (dos_hdr.e_magic != IMAGE_DOS_SIGNATURE) || (dos_hdr.e_lfanew <= 0))
        {
            sendstring_plaintext(s, WDEP_STATUS_415);
            __leave;
        }

        iobytes = 0;
        memset(&ovl, 0, sizeof(ovl));
        ovl.Offset = dos_hdr.e_lfanew;
        if (!ReadFile(hf, &dwSignature, sizeof(dwSignature), &iobytes, &ovl))
        {
            sendstring_plaintext(s, WDEP_STATUS_403);
            __leave;
        }
        if ((iobytes != sizeof(dwSignature)) || (dwSignature != IMAGE_NT_SIGNATURE))
        {
            sendstring_plaintext(s, WDEP_STATUS_415);
            __leave;
        }

        iobytes = 0;
        memset(&ovl, 0, sizeof(ovl));
        ovl.Offset = dos_hdr.e_lfanew + sizeof(dwSignature);
        if (!ReadFile(hf, &nt_file_hdr, sizeof(nt_file_hdr), &iobytes, &ovl))
        {
            sendstring_plaintext(s, WDEP_STATUS_403);
            __leave;
        }
        if (iobytes != sizeof(nt_file_hdr))
        {
            sendstring_plaintext(s, WDEP_STATUS_415);
            __leave;
        }

        iobytes = 0;
        memset(&ovl, 0, sizeof(ovl));
        ovl.Offset = dos_hdr.e_lfanew + sizeof(dwSignature) + IMAGE_SIZEOF_FILE_HEADER;

#pragma region CHECKSUM
        HANDLE hm = CreateFileMapping(hf, NULL, PAGE_READONLY, 0, 0, NULL);
        if (hm)
        {
            PVOID mapping = MapViewOfFile(hm, FILE_MAP_READ, 0, 0, 0);
            CloseHandle(hm);
            if (mapping)
            {
                opt_file_hdr.opt_file_hdr64 = (PIMAGE_OPTIONAL_HEADER64)((PBYTE)mapping + ovl.Offset);
                dwRealChecksum = calc_mapped_file_chksum(mapping, fileinfo.nFileSizeLow, (PUSHORT)&opt_file_hdr.opt_file_hdr64->CheckSum);
                UnmapViewOfFile(mapping);
            }
        }
#pragma endregion

        szOptAndSections = nt_file_hdr.SizeOfOptionalHeader + nt_file_hdr.NumberOfSections * IMAGE_SIZEOF_SECTION_HEADER;
        if (szOptAndSections < PAGE_SIZE)
            szOptAndSections = PAGE_SIZE;
        opt_file_hdr.opt_file_hdr64 = VirtualAllocEx(
            GetCurrentProcess(), NULL, szOptAndSections, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
        if (!opt_file_hdr.opt_file_hdr64)
        {
            sendstring_plaintext(s, WDEP_STATUS_500);
            __leave;
        }

        if (!ReadFile(hf, opt_file_hdr.opt_file_hdr64, szOptAndSections, &iobytes, &ovl))
        {
            sendstring_plaintext(s, WDEP_STATUS_403);
            __leave;
        }
        /*
        if (iobytes != szOptAndSections)
        {
            sendstring_plaintext(s, WDEP_STATUS_415);
            __leave;
        }
        */
        sections = (PIMAGE_SECTION_HEADER)((PBYTE)opt_file_hdr.opt_file_hdr64 + nt_file_hdr.SizeOfOptionalHeader);

        context->is_32bit = (opt_file_hdr.opt_file_hdr64->Magic == IMAGE_NT_OPTIONAL_HDR32_MAGIC);

        switch (opt_file_hdr.opt_file_hdr64->Magic)
        {
        case IMAGE_NT_OPTIONAL_HDR32_MAGIC:
        case IMAGE_NT_OPTIONAL_HDR64_MAGIC:
        {
            /* checking for sections continuity */
            if (nt_file_hdr.NumberOfSections == 0)
            {
                vsize = PAGE_ALIGN(max((ULONG)dos_hdr.e_lfanew, opt_file_hdr.opt_file_hdr64->SizeOfImage));
            }
            else
            {
                vsize = sections[0].VirtualAddress;
            }

            for (c = 0; c < nt_file_hdr.NumberOfSections; ++c)
            {
                if (((sections[c].VirtualAddress % opt_file_hdr.opt_file_hdr64->SectionAlignment) != 0) ||
                    (sections[c].VirtualAddress != vsize))
                {
                    sendstring_plaintext(s, WDEP_STATUS_415);
                    __leave;
                }

                tsize = sections[c].Misc.VirtualSize;
                psize = sections[c].SizeOfRawData;
                if ((tsize | psize) == 0)
                {
                    sendstring_plaintext(s, WDEP_STATUS_415);
                    __leave;
                }

                if (tsize == 0)
                    tsize = psize;

                vsize += ALIGN_UP(tsize, opt_file_hdr.opt_file_hdr64->SectionAlignment);
            }

            vsize = PAGE_ALIGN(vsize);

            if (vsize != PAGE_ALIGN(opt_file_hdr.opt_file_hdr64->SizeOfImage))
            {
                sendstring_plaintext(s, WDEP_STATUS_415);
                __leave;
            }
            break;
        }
        default:
            sendstring_plaintext(s, WDEP_STATUS_415);
            __leave;
            break;
        }

        /* End of image validation. Begin image loading */

        if (fUseReloc) {
            startAddress = minAppAddress;
        }
        else {
            startAddress = DEFAULT_APP_ADDRESS;
        }

        // allocate image buffer below 4GB for x86-32 compatibility
        for (c = startAddress; c < 0x40000000; c += 0x10000)
        {
            module = VirtualAllocEx(GetCurrentProcess(), (LPVOID)(ULONG_PTR)c, vsize, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
            if (module)
                break;
        }

        if (!module)
        {
            sendstring_plaintext(s, WDEP_STATUS_500);
            __leave;
        }

        iobytes = 0;
        memset(&ovl, 0, sizeof(ovl));

        switch (opt_file_hdr.opt_file_hdr64->Magic)
        {
        case IMAGE_NT_OPTIONAL_HDR32_MAGIC:
        case IMAGE_NT_OPTIONAL_HDR64_MAGIC:
        {
            if (nt_file_hdr.NumberOfSections == 0)
            {
                psize = PAGE_ALIGN(
                    max((ULONG)dos_hdr.e_lfanew,
                        opt_file_hdr.opt_file_hdr64->SizeOfImage));
            }
            else
            {
                psize = ALIGN_UP(
                    max((ULONG)dos_hdr.e_lfanew, opt_file_hdr.opt_file_hdr64->SizeOfHeaders),
                    opt_file_hdr.opt_file_hdr64->FileAlignment);
            }

            if (!ReadFile(hf, module, psize, &iobytes, &ovl))
            {
                sendstring_plaintext(s, WDEP_STATUS_403);
                __leave;
            }

            for (c = 0; c < nt_file_hdr.NumberOfSections; ++c)
            {
                
                if (sections[c].PointerToRawData == 0)
                    continue;

                memset(&ovl, 0, sizeof(ovl));
                ovl.Offset = ALIGN_DOWN(sections[c].PointerToRawData, opt_file_hdr.opt_file_hdr64->FileAlignment);

                tsize = sections[c].Misc.VirtualSize;
                psize = sections[c].SizeOfRawData;

                if (tsize == 0)
                    tsize = psize;
                tsize = min(tsize, psize);
                tsize = ALIGN_UP(tsize, opt_file_hdr.opt_file_hdr64->FileAlignment);

                iobytes = 0;
                if (!ReadFile(hf, module + sections[c].VirtualAddress, tsize, &iobytes, &ovl))
                {
                    sendstring_plaintext(s, WDEP_STATUS_403);
                    __leave;
                }
            }
            break;
        }
        default:
            sendstring_plaintext(s, WDEP_STATUS_415);
            __leave;
            break;
        }

        if (fUseReloc) {
            switch (opt_file_hdr.opt_file_hdr64->Magic)
            {
            case IMAGE_NT_OPTIONAL_HDR32_MAGIC:
                get_pe_dirbase_size(opt_file_hdr.opt_file_hdr32, IMAGE_DIRECTORY_ENTRY_BASERELOC, dir_base, dir_size);
                if (dir_base)
                    relocimage64(module, (LPVOID)(ULONG_PTR)opt_file_hdr.opt_file_hdr32->ImageBase,
                        (PIMAGE_BASE_RELOCATION)(module + dir_base), dir_size);
                break;

            case IMAGE_NT_OPTIONAL_HDR64_MAGIC:
                get_pe_dirbase_size(opt_file_hdr.opt_file_hdr64, IMAGE_DIRECTORY_ENTRY_BASERELOC, dir_base, dir_size);
                if (dir_base)
                    relocimage64(module, (LPVOID)(DWORD_PTR)opt_file_hdr.opt_file_hdr64->ImageBase,
                        (PIMAGE_BASE_RELOCATION)(module + dir_base), dir_size);
                break;
            }
        }

        status = 1;
    }
    __finally
    {
        if (_abnormal_termination()) {
            printf("exception in pe32open\r\n");
        }

        if ((module) && (!status))
        {
            VirtualFreeEx(GetCurrentProcess(), module, 0, MEM_RELEASE);
            module = NULL;
        }

        if (opt_file_hdr.opt_file_hdr64)
            VirtualFreeEx(GetCurrentProcess(), opt_file_hdr.opt_file_hdr64, 0, MEM_RELEASE);

        CloseHandle(hf);
    }

    if (module) {
        StringCchPrintf(text, ARRAYSIZE(text),
            WDEP_STATUS_OK
            L"{\"fileinfo\":{"
            L"\"FileAttributes\":%u,"
            L"\"CreationTimeLow\":%u,"
            L"\"CreationTimeHigh\":%u,"
            L"\"LastWriteTimeLow\":%u,"
            L"\"LastWriteTimeHigh\":%u,"
            L"\"FileSizeHigh\":%u,"
            L"\"FileSizeLow\":%u,"
            L"\"RealChecksum\":%u}}\r\n",
            fileinfo.dwFileAttributes,
            fileinfo.ftCreationTime.dwLowDateTime,
            fileinfo.ftCreationTime.dwHighDateTime,
            fileinfo.ftLastWriteTime.dwLowDateTime,
            fileinfo.ftLastWriteTime.dwHighDateTime,
            fileinfo.nFileSizeHigh,
            fileinfo.nFileSizeLow,
            dwRealChecksum
        );
        sendstring_plaintext(s, text);
    }

    return module;
}

BOOL pe32close(PBYTE module)
{
    if (module)
        return VirtualFreeEx(GetCurrentProcess(), module, 0, MEM_RELEASE);

    return FALSE;
}
