#include "WinCseLib.h"
#include "AwsS3.hpp"
#include <filesystem>
#include <fstream>
#include <cinttypes>


//
// !! ���̊֐��̓f�o�b�O���ɂ��X���b�h�E�Z�[�t�ł͂Ȃ��̂ŁA�����ɔz�u���Ă���
//
// ListObjectsV2 API �����s�����ʂ������̃|�C���^�̎w���ϐ��ɕۑ�����
// �����̏����ɍ��v����I�u�W�F�N�g��������Ȃ��Ƃ��� false ��ԋp
//
bool AwsS3::awsapiListObjectsV2(CALLER_ARG const std::wstring& argBucket, const std::wstring& argKey,
    std::vector<std::shared_ptr<FSP_FSCTL_DIR_INFO>>* pDirInfoList,
    const int limit, const bool delimiter)
{
    NEW_LOG_BLOCK();
    APP_ASSERT(pDirInfoList);

    std::vector<std::shared_ptr<FSP_FSCTL_DIR_INFO>> dirInfoList;

    /*
    const auto bucketRegion{ getBucketRegion(CONT_CALLER argBucket) };
    if (bucketRegion != mRegion)
    {
    // �o�P�b�g�̃��[�W�����ɉ������G���h�|�C���g���蓮�Őݒ�
    std::stringstream ss;
    ss << "s3.";
    ss << bucketRegion;
    ss << ".amazon.com";

    Aws::String endpoint{ ss.str().c_str() };

    mClient.ptr->OverrideEndpoint(endpoint);
    }
    */
    Aws::S3::Model::ListObjectsV2Request request;
    request.SetBucket(WC2MB(argBucket).c_str());

    if (delimiter)
    {
        request.WithDelimiter("/");
    }

    const auto argKeyLen = argKey.length();
    if (argKeyLen > 0)
    {
        request.SetPrefix(WC2MB(argKey).c_str());
    }

    UINT64 commonPrefixTime = UINT64_MAX;
    std::set<std::wstring> already;

    Aws::String continuationToken;                              // Used for pagination.

    do
    {
        if (!continuationToken.empty())
        {
            request.SetContinuationToken(continuationToken);
        }

        const auto outcome = mClient.ptr->ListObjectsV2(request);
        if (!outcomeIsSuccess(outcome))
        {
            traceW(L"fault: ListObjectsV2");

            return false;
        }

        const auto& result = outcome.GetResult();

        //
        // �f�B���N�g���E�G���g���̂��ߍŏ��Ɉ�ԌÂ��^�C���X�^���v�����W
        // * CommonPrefix �ɂ̓^�C���X�^���v���Ȃ�����
        //
        for (const auto& obj : result.GetContents())
        {
            const auto lastModTime = UtcMillisToWinFileTime(obj.GetLastModified().Millis());

            if (lastModTime < commonPrefixTime)
            {
                commonPrefixTime = lastModTime;
            }
        }

        if (commonPrefixTime == UINT64_MAX)
        {
            // �^�C���X�^���v���̎�ł��Ȃ���ΎQ�ƃf�B���N�g���̂��̂��̗p

            commonPrefixTime = mWorkDirTime;
        }

        // �f�B���N�g���̎��W
        for (const auto& obj : result.GetCommonPrefixes())
        {
            const std::string fullPath{ obj.GetPrefix().c_str() };      // Aws::String -> std::string

            traceA("GetCommonPrefixes: %s", fullPath.c_str());

            std::wstring key{ MB2WC(fullPath.substr(argKeyLen)) };
            if (!key.empty())
            {
                if (key.back() == L'/')
                {
                    key.pop_back();
                }
            }

            if (key.empty())
            {
                key = L".";
            }

            APP_ASSERT(!key.empty());

            if (std::find(already.begin(), already.end(), key) != already.end())
            {
                traceW(L"%s: already added", key.c_str());
                continue;
            }

            already.insert(key);

            auto dirInfo = mallocDirInfoW(key, argBucket);
            APP_ASSERT(dirInfo);

            UINT32 FileAttributes = FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_READONLY;

            if (key != L"." && key != L".." && key[0] == L'.')
            {
                // �B���t�@�C��
                FileAttributes |= FILE_ATTRIBUTE_HIDDEN;
            }

            dirInfo->FileInfo.FileAttributes = FileAttributes;

            dirInfo->FileInfo.CreationTime = commonPrefixTime;
            dirInfo->FileInfo.LastAccessTime = commonPrefixTime;
            dirInfo->FileInfo.LastWriteTime = commonPrefixTime;
            dirInfo->FileInfo.ChangeTime = commonPrefixTime;

            //dirInfoList.emplace_back(dirInfo, free_deleter<FSP_FSCTL_DIR_INFO>);
            dirInfoList.push_back(dirInfo);

            if (limit > 0)
            {
                if (dirInfoList.size() >= limit)
                {
                    goto exit;
                }
            }

            if (mMaxObjects > 0)
            {
                if (dirInfoList.size() >= mMaxObjects)
                {
                    traceW(L"warning: over max-objects(%d)", mMaxObjects);

                    goto exit;
                }
            }
        }

        // �t�@�C���̎��W
        for (const auto& obj : result.GetContents())
        {
            const std::string fullPath{ obj.GetKey().c_str() };     // Aws::String -> std::string

            traceA("GetContents: %s", fullPath.c_str());

            bool isDir = false;

            std::wstring key{ MB2WC(fullPath.substr(argKeyLen)) };
            if (!key.empty())
            {
                if (key.back() == L'/')
                {
                    isDir = true;
                    key.pop_back();
                }
            }

            if (key.empty())
            {
                isDir = true;
                key = L".";
            }

            APP_ASSERT(!key.empty());

            if (std::find(already.begin(), already.end(), key) != already.end())
            {
                traceW(L"%s: already added", key.c_str());
                continue;
            }

            already.insert(key);

            auto dirInfo = mallocDirInfoW(key, argBucket);
            APP_ASSERT(dirInfo);

            UINT32 FileAttributes = FILE_ATTRIBUTE_READONLY;

            if (key != L"." && key != L".." && key[0] == L'.')
            {
                // �B���t�@�C��
                FileAttributes |= FILE_ATTRIBUTE_HIDDEN;
            }

            if (isDir)
            {
                FileAttributes |= FILE_ATTRIBUTE_DIRECTORY;
            }
            else
            {
                dirInfo->FileInfo.FileSize = obj.GetSize();
                dirInfo->FileInfo.AllocationSize = (dirInfo->FileInfo.FileSize + ALLOCATION_UNIT - 1) / ALLOCATION_UNIT * ALLOCATION_UNIT;
            }

            dirInfo->FileInfo.FileAttributes |= FileAttributes;

            const auto lastModTime = UtcMillisToWinFileTime(obj.GetLastModified().Millis());

            dirInfo->FileInfo.CreationTime = lastModTime;
            dirInfo->FileInfo.LastAccessTime = lastModTime;
            dirInfo->FileInfo.LastWriteTime = lastModTime;
            dirInfo->FileInfo.ChangeTime = lastModTime;

            //dirInfoList.emplace_back(dirInfo, free_deleter<FSP_FSCTL_DIR_INFO>);
            dirInfoList.push_back(dirInfo);

            if (limit > 0)
            {
                if (dirInfoList.size() >= limit)
                {
                    // ���ʃ��X�g�������Ŏw�肵�� limit �ɓ��B

                    goto exit;
                }
            }

            if (mMaxObjects > 0)
            {
                if (dirInfoList.size() >= mMaxObjects)
                {
                    // ���ʃ��X�g�� ini �t�@�C���Ŏw�肵���ő�l�ɓ��B

                    traceW(L"warning: over max-objects(%d)", mMaxObjects);

                    goto exit;
                }
            }
        }

        continuationToken = result.GetNextContinuationToken();
    } while (!continuationToken.empty());

exit:
    *pDirInfoList = dirInfoList;

    return !dirInfoList.empty();
}

#if 0
// ����I�ȏ󋵂ł������삵�Ȃ��̂Œ���

static std::mutex gGuard;

#define THREAD_SAFE_4DEBUG() \
	std::lock_guard<std::mutex> lock_(gGuard); \
    traceW(L"!!! *** WARNNING *** THREAD_SAFE_4DEBUG() ENABLE !!!")

#else
#define THREAD_SAFE_4DEBUG()

#endif


bool AwsS3::headObject(CALLER_ARG const std::wstring& argBucket,
    const std::wstring& argKey, FSP_FSCTL_FILE_INFO* pFileInfo)
{
    NEW_LOG_BLOCK();
    THREAD_SAFE_4DEBUG();
    APP_ASSERT(!argBucket.empty());
    APP_ASSERT(!argKey.empty());
    APP_ASSERT(argKey.back() != L'/');

    traceW(L"bucket: %s, key: %s", argBucket.c_str(), argKey.c_str());

    std::shared_ptr<FSP_FSCTL_DIR_INFO> dirInfo;

    {
        std::vector<std::shared_ptr<FSP_FSCTL_DIR_INFO>> dirInfoList;

        if (mObjectCache.getPositive(CONT_CALLER argBucket, argKey, -1, false, &dirInfoList))
        {
            // -1 �Ō������Ă���̂ňꌏ�݂̂ł���͂�
            APP_ASSERT(dirInfoList.size() == 1);

            traceW(L"found in cache");
            dirInfo = dirInfoList[0];
        }
    }

    if (!dirInfo)
    {
        traceW(L"not found in cache");

        // �l�K�e�B�u�E�L���b�V���𒲂ׂ�
        if (mObjectCache.isInNegative(CONT_CALLER argBucket, argKey, -1, false))
        {
            traceW(L"found in negative cache");
            return false;
        }

        traceW(L"do HeadObject");

        Aws::S3::Model::HeadObjectRequest request;
        request.SetBucket(WC2MB(argBucket).c_str());
        request.SetKey(WC2MB(argKey).c_str());

        const auto outcome = mClient.ptr->HeadObject(request);
        if (!outcomeIsSuccess(outcome))
        {
            // HeadObject �̎��s���G���[�A�܂��̓I�u�W�F�N�g��������Ȃ�

            // �l�K�e�B�u�E�L���b�V���ɓo�^
            traceW(L"add negative");
            mObjectCache.addNegative(CONT_CALLER argBucket, argKey, -1, false);

            traceW(L"object not found");
            return false;
        }

        const auto& result = outcome.GetResult();

        dirInfo = mallocDirInfoW(argKey, argBucket);
        APP_ASSERT(dirInfo);

        const auto FileSize = result.GetContentLength();
        const auto FileTime = UtcMillisToWinFileTime(result.GetLastModified().Millis());

        UINT32 FileAttributes = FILE_ATTRIBUTE_READONLY;

        if (argKey != L"." && argKey != L".." && argKey[0] == L'.')
        {
            FileAttributes |= FILE_ATTRIBUTE_HIDDEN;
        }

        dirInfo->FileInfo.FileAttributes = FileAttributes;
        dirInfo->FileInfo.FileSize = FileSize;
        dirInfo->FileInfo.AllocationSize = (FileSize + ALLOCATION_UNIT - 1) / ALLOCATION_UNIT * ALLOCATION_UNIT;
        dirInfo->FileInfo.CreationTime = FileTime;
        dirInfo->FileInfo.LastAccessTime = FileTime;
        dirInfo->FileInfo.LastWriteTime = FileTime;
        dirInfo->FileInfo.ChangeTime = FileTime;
        dirInfo->FileInfo.IndexNumber = HashString(argBucket + L'/' + argKey);

        // �L���b�V���ɃR�s�[
        {
            // �ꌏ�݂̂̃��X�g�ɂ��� (�L���b�V���̌`���ɍ��킹��)
            std::vector<std::shared_ptr<FSP_FSCTL_DIR_INFO>> dirInfoList{ dirInfo };

            mObjectCache.setPositive(CONT_CALLER argBucket, argKey, -1, false, dirInfoList);
        }
    }

    if (pFileInfo)
    {
        (*pFileInfo) = dirInfo->FileInfo;
    }

    return true;
}

bool AwsS3::listObjects(CALLER_ARG const std::wstring& argBucket, const std::wstring& argKey,
    std::vector<std::shared_ptr<FSP_FSCTL_DIR_INFO>>* pDirInfoList,
    const int limit, const bool delimiter)
{
    NEW_LOG_BLOCK();
    THREAD_SAFE_4DEBUG();
    APP_ASSERT(!argBucket.empty());
    APP_ASSERT(argBucket.back() != L'/');

    if (!argKey.empty())
    {
        APP_ASSERT(argKey.back() == L'/');
    }

    traceW(L"bucket: %s, key: %s, limit: %d", argBucket.c_str(), argKey.c_str(), limit);

    std::vector<std::shared_ptr<FSP_FSCTL_DIR_INFO>> dirInfoList;

    const bool inCache = mObjectCache.getPositive(CONT_CALLER argBucket, argKey, limit, delimiter, &dirInfoList);

    if (inCache)
    {
        // �L���b�V�����Ɍ�������

        traceW(L"found in cache");
    }
    else
    {
        traceW(L"not found in cache");

        if (mObjectCache.isInNegative(CONT_CALLER argBucket, argKey, limit, delimiter))
        {
            traceW(L"found in negative cache");
            return false;
        }

        traceW(L"call doListObjectV2");

        if (!awsapiListObjectsV2(CONT_CALLER argBucket, argKey, &dirInfoList, limit, delimiter))
        {
            // ListObjectsV2 �̎��s���G���[�A�܂��̓I�u�W�F�N�g��������Ȃ�

            // �l�K�e�B�u�E�L���b�V���ɓo�^
            traceW(L"add negative");
            mObjectCache.addNegative(CONT_CALLER argBucket, argKey, limit, delimiter);

            traceW(L"object not found");

            return false;
        }

        // �L���b�V���ɃR�s�[

        mObjectCache.setPositive(CONT_CALLER argBucket, argKey, limit, delimiter, dirInfoList);
    }

    // �o�P�b�g�̒�����̎��� dirInfoList.size()==0 �ƂȂ�

    if (pDirInfoList)
    {
        *pDirInfoList = std::move(dirInfoList);
    }

    return true;
}

HANDLE AwsS3::openObject(CALLER_ARG const std::wstring& argBucket,
    const std::wstring& argKey, UINT32 CreateOptions, UINT32 GrantedAccess)
{
    NEW_LOG_BLOCK();
    THREAD_SAFE_4DEBUG();
    APP_ASSERT(!argBucket.empty());
    APP_ASSERT(!argKey.empty());
    APP_ASSERT(argKey.back() != L'/');

    const std::wstring localPath{ mCacheDir + L'\\' + EncodeFileNameToLocalNameW(argBucket + L'/' + argKey) };

    bool needGet = false;

    struct _stat st;
    if (_wstat(localPath.c_str(), &st) == 0)
    {
        // ���[�J���ɃL���b�V���E�t�@�C�������݂���

        // Windows �ł� S_ISREG() �}�N�����g���Ȃ��̂� fs �ő�p
        APP_ASSERT(std::filesystem::is_regular_file(localPath));

        FSP_FSCTL_FILE_INFO fileInfo = {};

        if (this->headObject(CONT_CALLER argBucket, argKey, &fileInfo))
        {
            // ���[�J���E�t�@�C���̍X�V�����Ɣ�r

            const auto mtime = UtcMillisToWinFileTime(st.st_mtime * 1000);

            if (fileInfo.CreationTime > mtime)
            {
                // �����[�g�E�t�@�C�����X�V����Ă���̂ōĎ擾

                needGet = true;
            }
        }
    }
    else
    {
        // ���[�J���ɃL���b�V���E�t�@�C�������݂��Ȃ��̂Ŏ擾

        needGet = true;
    }

    traceW(L"needGet: %s", needGet ? L"true" : L"false");

    if (needGet)
    {
        Aws::S3::Model::GetObjectRequest request;
        request.SetBucket(WC2MB(argBucket).c_str());
        request.SetKey(WC2MB(argKey).c_str());

        const auto outcome = mClient.ptr->GetObject(request);
        if (!outcomeIsSuccess(outcome))
        {
            traceW(L"fault: GetObject");
            return INVALID_HANDLE_VALUE;
        }

        const auto& result = outcome.GetResult();
        std::ofstream ofs{ localPath, std::ios::binary };
        if (!ofs)
        {
            traceW(L"fault: ofstream");
            return INVALID_HANDLE_VALUE;
        }

        const std::streampos begin(ofs.tellp());
        ofs << result.GetBody().rdbuf();
        const std::streampos end(ofs.tellp());

        ofs.close();

        const auto wn = (uint64_t)(end - begin);

        traceW(L"write file size %" PRIu64, wn);
    }

    //
    ULONG CreateFlags = FILE_FLAG_BACKUP_SEMANTICS;
    if (CreateOptions & FILE_DELETE_ON_CLOSE)
        CreateFlags |= FILE_FLAG_DELETE_ON_CLOSE;

    HANDLE h = ::CreateFileW(localPath.c_str(),
        GrantedAccess, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, 0,
        OPEN_EXISTING, CreateFlags, 0);
    if (INVALID_HANDLE_VALUE == h)
    {
        //return FspNtStatusFromWin32(GetLastError());
        traceW(L"fault: ofstream");
        return INVALID_HANDLE_VALUE;

    }

    return h;
}

// EOF