#pragma once

//
// �I���W�i���� "passthrough.c" �Ɠ��������������邽�߂̃X�C�b�`
//
#define WINFSP_PASSTHROUGH				(0)

//
// "ntstatus.h" �� include ���邽�߂ɂ͈ȉ��̋L�q (define/undef) ���K�v����
// �������Ƃ� "winfsp/winfsp.h" �ōs���Ă���̂ŃR�����g��
// 
//#define WIN32_NO_STATUS
//#include <windows.h>
//#undef WIN32_NO_STATUS

#pragma warning(push, 0)
#include <winfsp/winfsp.h>
#pragma warning(pop)

//
// passthrough.c �ɒ�`����Ă������̂̂����A�A�v���P�[�V������
// �K�v�ƂȂ���̂��O����
//
#define ALLOCATION_UNIT                 (4096)

typedef struct
{
#if WINFSP_PASSTHROUGH
    // �Ԉ���ė��p����Ȃ��悤�ɃR�����g��

    HANDLE Handle;
#endif
    PVOID DirBuffer;

    // �ǉ����
    struct
    {
        PWSTR FileName;
        FSP_FSCTL_FILE_INFO FileInfo;
        UINT32 CreateOptions;
        UINT32 GrantedAccess;
    }
    Open;

    struct
    {
        HANDLE Handle;
    }
    Local;
}
PTFS_FILE_CONTEXT;


// EOF