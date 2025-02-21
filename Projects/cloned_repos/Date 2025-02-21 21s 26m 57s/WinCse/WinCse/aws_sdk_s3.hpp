#pragma once
//
// AWS SDK �֘A
//
// �����̃w�b�_�ɂ�� set<string> �� vector<string> �̕ϐ���
// Aws::String �̂��̂ɂȂ��Ă��܂�
// �悭�킩��Ȃ����A��������܂ł͊�{�I�� wstring ���g��
// sdk �̊֐��Ƃ̂����� string ���K�v�ȏꍇ�� c_str() ���o�R����
//

#include "internal_undef_alloc.h"

// https://github.com/aws/aws-sdk-cpp/issues/3209
#define USE_IMPORT_EXPORT
//#define USE_WINDOWS_DLL_SEMANTICS

#pragma warning(push, 0)
#include <aws/core/Aws.h>
#include <aws/core/auth/AWSCredentials.h>
#include <aws/core/auth/AWSCredentialsProvider.h>
#include <aws/s3/S3Client.h>

#include <aws/s3/model/BucketLocationConstraint.h>
#include <aws/s3/model/Bucket.h>
#include <aws/s3/model/GetBucketLocationRequest.h>
#include <aws/s3/model/HeadBucketRequest.h>
#include <aws/s3/model/ListBucketsRequest.h>
#include <aws/s3/model/HeadObjectRequest.h>
#include <aws/s3/model/ListObjectsV2Request.h>
#include <aws/s3/model/GetObjectRequest.h>
#pragma warning(pop)

#undef USE_IMPORT_EXPORT

#include "internal_define_alloc.h"

// EOF