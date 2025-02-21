#include "WinCseLib.h"
#include "AwsS3.hpp"
#include <cinttypes>


std::wstring AwsS3::getBucketRegion(CALLER_ARG const std::wstring& bucketName)
{
    NEW_LOG_BLOCK();

    std::wstring bucketRegion;

    traceW(L"bucketName: %s", bucketName.c_str());

    if (mBucketCache.findRegion(CONT_CALLER bucketName, &bucketRegion))
    {
        traceW(L"hit in cache, region is %s", bucketRegion.c_str());
    }
    else
    {
        // �L���b�V���ɑ��݂��Ȃ�

        traceW(L"do GetBucketLocation()");

        namespace mapper = Aws::S3::Model::BucketLocationConstraintMapper;

        Aws::S3::Model::GetBucketLocationRequest request;
        request.SetBucket(WC2MB(bucketName).c_str());

        const auto outcome = mClient.ptr->GetBucketLocation(request);
        if (outcomeIsSuccess(outcome))
        {
            const auto& result = outcome.GetResult();
            const auto& location = result.GetLocationConstraint();

            bucketRegion = MB2WC(mapper::GetNameForBucketLocationConstraint(location));

            traceW(L"success, region is %s", bucketRegion.c_str());
        }
        
        if (bucketRegion.empty())
        {
            bucketRegion = MB2WC(AWS_DEFAULT_REGION);

            traceW(L"error, fall back region is %s", bucketRegion.c_str());
        }

        mBucketCache.updateRegion(CONT_CALLER bucketName, bucketRegion);
    }

    return bucketRegion;
}

bool AwsS3::headBucket(CALLER_ARG const std::wstring& bucketName)
{
    NEW_LOG_BLOCK();
    APP_ASSERT(!bucketName.empty());
    APP_ASSERT(bucketName.back() != L'/');

    traceW(L"bucket: %s", bucketName.c_str());

    if (!isInBucketFiltersW(bucketName))
    {
        // �o�P�b�g�t�B���^�ɍ��v���Ȃ�
        traceW(L"%s: is not in filters, skip", bucketName.c_str());

        return false;
    }

    // �L���b�V������T��
    const auto bucket{ mBucketCache.find(CONT_CALLER bucketName) };
    if (bucket)
    {
        traceW(L"hit in buckets cache");
    }
    else
    {
        traceW(L"warn: no match");

        Aws::S3::Model::HeadBucketRequest request;
        request.SetBucket(WC2MB(bucketName).c_str());

        const auto outcome = mClient.ptr->HeadBucket(request);
        if (!outcomeIsSuccess(outcome))
        {
            traceW(L"fault: HeadBucket");
            return false;
        }
    }

    const std::wstring bucketRegion{ getBucketRegion(CONT_CALLER bucketName) };
    if (bucketRegion != mRegion)
    {
        // �o�P�b�g�̃��[�W�������قȂ�̂ŋ���

        traceW(L"%s: no match bucket-region", bucketRegion.c_str());
        return false;
    }

    traceW(L"success");

    return true;
}

//
// Head ����n�܂�֐��͖߂�l�݂̂ő��݂̗L�����肪�\
// List ����n�܂�֐��̏ꍇ�́A��L�ɉ����Ė߂��ꂽ���X�g�̌������m�F����
//
bool AwsS3::listBuckets(CALLER_ARG
    std::vector<std::shared_ptr<FSP_FSCTL_DIR_INFO>>* pDirInfoList,
    const std::vector<std::wstring>& options)
{
    NEW_LOG_BLOCK();

    std::vector<std::shared_ptr<FSP_FSCTL_DIR_INFO>> dirInfoList;

    if (mBucketCache.empty(CONT_CALLER0))
    {
        traceW(L"cache empty");

        // �o�P�b�g�ꗗ�̎擾

        Aws::S3::Model::ListBucketsRequest request;

        const auto outcome = mClient.ptr->ListBuckets(request);
        if (!outcomeIsSuccess(outcome))
        {
            traceW(L"fault: ListBuckets");
            return false;
        }

        const auto& result = outcome.GetResult();

        for (const auto& bucket : result.GetBuckets())
        {
            const std::wstring bucketName{ MB2WC(bucket.GetName()) };

            if (!isInBucketFiltersW(bucketName))
            {
                // �o�P�b�g���ɂ��t�B���^�����O

                traceW(L"%s: is not in filters, skip", bucketName.c_str());
                continue;
            }

            std::wstring bucketRegion;
            if (mBucketCache.findRegion(CONT_CALLER bucketName, &bucketRegion))
            {
                // �قȂ郊�[�W�����̃o�P�b�g�͖���

                if (bucketRegion != mRegion)
                {
                    traceW(L"%s: no match region, skip", bucketRegion.c_str());
                    continue;
                }
            }

            auto dirInfo = mallocDirInfoW(bucketName, L"");
            APP_ASSERT(dirInfo);

            const auto FileTime = UtcMillisToWinFileTime(bucket.GetCreationDate().Millis());

            dirInfo->FileInfo.FileAttributes = FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_READONLY;
            dirInfo->FileInfo.CreationTime = FileTime;
            dirInfo->FileInfo.LastAccessTime = FileTime;
            dirInfo->FileInfo.LastWriteTime = FileTime;
            dirInfo->FileInfo.ChangeTime = FileTime;

            //dirInfoList.emplace_back(dirInfo, free_deleter<FSP_FSCTL_DIR_INFO>);
            dirInfoList.push_back(dirInfo);

            if (mMaxBuckets > 0)
            {
                if (dirInfoList.size() >= mMaxBuckets)
                {
                    break;
                }
            }
        }

        traceW(L"update cache");

        // �L���b�V���ɃR�s�[
        mBucketCache.save(CONT_CALLER dirInfoList);
    }
    else
    {
        // �L���b�V������R�s�[
        mBucketCache.load(CONT_CALLER mRegion, dirInfoList);

        traceW(L"use cache: size=%zu", dirInfoList.size());
    }

    bool ret = false;

    if (pDirInfoList)
    {
        if (options.empty())
        {
            // ���o�������Ȃ��̂ŁA�S�Ē�

            *pDirInfoList = std::move(dirInfoList);
            ret = true;
        }
        else
        {
            // ���o�����Ɉ�v������̂��

            std::vector<std::shared_ptr<FSP_FSCTL_DIR_INFO>> optsDirInfoList;

            for (const auto& dirInfo : dirInfoList)
            {
                const std::wstring bucketName{ dirInfo->FileNameBuf };
                const auto it = std::find(options.begin(), options.end(), bucketName);

                if (it != options.end())
                {
                    optsDirInfoList.push_back(dirInfo);
                }

                if (optsDirInfoList.size() == options.size())
                {
                    break;
                }
            }

            if (!optsDirInfoList.empty())
            {
                *pDirInfoList = std::move(optsDirInfoList);
                ret = true;
            }
        }
    }
    else
    {
        ret = !dirInfoList.empty();
    }

    return ret;
}

// EOF