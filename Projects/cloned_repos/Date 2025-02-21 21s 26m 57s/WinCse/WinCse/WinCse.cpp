#include "WinCseLib.h"
#include "WinCse.hpp"
#include <filesystem>

#undef traceA


std::atomic<int> LogBlock::mCounter(0);

WinCse::WinCse(const wchar_t* tmpdir, const wchar_t* iniSection,
	IWorker* delayedWorker, IWorker* idleWorker, ICloudStorage* storage) :
	mTempDir(tmpdir), mIniSection(iniSection),
	mDelayedWorker(delayedWorker),	mIdleWorker(idleWorker),
	mStorage(storage),
	mMaxFileSize(-1),
	mIgnoreFileNamePattern{ LR"(.*\\(desktop\.ini|autorun\.inf|thumbs\.db)$)", std::regex_constants::icase }
{
	NEW_LOG_BLOCK();

	APP_ASSERT(std::filesystem::exists(tmpdir));
	APP_ASSERT(std::filesystem::is_directory(tmpdir));
	APP_ASSERT(iniSection);
	APP_ASSERT(storage);
	APP_ASSERT(delayedWorker);
	APP_ASSERT(idleWorker);
}

WinCse::~WinCse()
{
	NEW_LOG_BLOCK();

	traceW(L"close handle");

	if (mFileRefHandle != INVALID_HANDLE_VALUE)
	{
		::CloseHandle(mFileRefHandle);
		mFileRefHandle = INVALID_HANDLE_VALUE;
	}

	if (mDirRefHandle != INVALID_HANDLE_VALUE)
	{
		::CloseHandle(mDirRefHandle);
		mDirRefHandle = INVALID_HANDLE_VALUE;
	}

	traceW(L"all done.");
}

bool WinCse::isIgnoreFileName(const wchar_t* arg)
{
	// desktop.ini �Ȃǃ��N�G�X�g�������߂�����͖̂�������

	return std::regex_match(std::wstring(arg), mIgnoreFileNamePattern);
}

//
// passthrough.c ����q��
//
NTSTATUS WinCse::HandleToInfo(HANDLE handle, PUINT32 PFileAttributes,
	PSECURITY_DESCRIPTOR SecurityDescriptor, SIZE_T* PSecurityDescriptorSize)
{
	NEW_LOG_BLOCK();

	FILE_ATTRIBUTE_TAG_INFO AttributeTagInfo = {};
	DWORD SecurityDescriptorSizeNeeded = 0;

	if (0 != PFileAttributes)
	{
		if (!::GetFileInformationByHandleEx(handle,
			FileAttributeTagInfo, &AttributeTagInfo, sizeof AttributeTagInfo))
		{
			return FspNtStatusFromWin32(::GetLastError());
		}

		traceW(L"FileAttributes: %u", AttributeTagInfo.FileAttributes);
		traceW(L"\tdetect: %s", AttributeTagInfo.FileAttributes & FILE_ATTRIBUTE_DIRECTORY ? L"dir" : L"file");

		*PFileAttributes = AttributeTagInfo.FileAttributes;
	}

	if (0 != PSecurityDescriptorSize)
	{
		if (!::GetKernelObjectSecurity(handle,
			OWNER_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION,
			SecurityDescriptor, (DWORD)*PSecurityDescriptorSize, &SecurityDescriptorSizeNeeded))
		{
			*PSecurityDescriptorSize = SecurityDescriptorSizeNeeded;
			return FspNtStatusFromWin32(::GetLastError());
		}

		traceW(L"SecurityDescriptorSizeNeeded: %u", SecurityDescriptorSizeNeeded);

		*PSecurityDescriptorSize = SecurityDescriptorSizeNeeded;
	}

	return STATUS_SUCCESS;
}

NTSTATUS WinCse::FileNameToFileInfo(const wchar_t* FileName, FSP_FSCTL_FILE_INFO* pFileInfo)
{
	NEW_LOG_BLOCK();
	APP_ASSERT(FileName);
	APP_ASSERT(pFileInfo);

	FSP_FSCTL_FILE_INFO fileInfo = {};

	bool isDir = false;
	bool isFile = false;

	if (wcscmp(FileName, L"\\") == 0)
	{
		// "\" �ւ̃A�N�Z�X�͎Q�Ɨp�f�B���N�g���̏����
		isDir = true;
		traceW(L"detect directory/1");

		GetFileInfoInternal(this->mDirRefHandle, &fileInfo);
	}
	else
	{
		// �����ɗ���̂� "\\bucket" ���� "\\bucket\\key" �̂�

		// DoGetSecurityByName() �Ɠ��l�̌��������āA���̌��ʂ� PFileContext
		// �� FileInfo �ɔ��f������

		const BucketKey bk{ FileName };
		if (!bk.OK)
		{
			traceW(L"illegal FileName: %s", FileName);

			return STATUS_INVALID_PARAMETER;
		}

		if (bk.HasKey)
		{
			// "\bucket\key" �̃p�^�[��

			// "key/" �ňꌏ�̂ݎ擾���āA���݂�����f�B���N�g�������݂����
			// ���肵�āA���̏����f�B���N�g�������Ƃ��č̗p

			std::vector<std::shared_ptr<FSP_FSCTL_DIR_INFO>> dirInfoList;

			//
			// SetDelimiter("/") ��ݒ肷��� CommonPrefix �Ŏ擾���Ă��܂�
			// CreationTime �Ȃǂ� 0 �ɂȂ��Ă��܂����� false
			//
			if (mStorage->listObjects(INIT_CALLER bk.bucket, bk.key + L'/', &dirInfoList, 1, false))
			{
				APP_ASSERT(!dirInfoList.empty());
				APP_ASSERT(dirInfoList.size() == 1);

				// �f�B���N�g�����̗p
				isDir= true;
				traceW(L"detect directory/2");

				// �f�B���N�g���̏ꍇ�� FSP_FSCTL_FILE_INFO �ɓK���Ȓl�𖄂߂�
				// ... �擾�����v�f�̏��([0]) ���t�@�C���̏ꍇ������̂ŁA�ҏW���K�v

				const auto& dirInfo(dirInfoList[0]);
				const auto FileTime = dirInfo->FileInfo.ChangeTime;

				fileInfo.FileAttributes = FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_READONLY;
				fileInfo.CreationTime = FileTime;
				fileInfo.LastAccessTime = FileTime;
				fileInfo.LastWriteTime = FileTime;
				fileInfo.ChangeTime = FileTime;
				fileInfo.IndexNumber = HashString(bk.bucket + L'/' + bk.key);
			}

			if (!isDir)
			{
				// �t�@�C�����̊��S��v�Ō���

				if (mStorage->headObject(INIT_CALLER bk.bucket, bk.key, &fileInfo))
				{
					// �t�@�C�����̗p
					isFile = true;
					traceW(L"detect file");
				}
			}
		}
		else
		{
			// "\bucket" �̃p�^�[��

			// HeadBucket �ł̓��^��񂪎擾�ł��Ȃ��̂� ListBuckets ���疼�O����v������̂��擾

			std::vector<std::shared_ptr<FSP_FSCTL_DIR_INFO>> dirInfoList;

			// ���O���w�肵�ă��X�g���擾

			const std::vector<std::wstring>& options = { bk.bucket };

			if (mStorage->listBuckets(INIT_CALLER &dirInfoList, options))
			{
				APP_ASSERT(!dirInfoList.empty());

				// �f�B���N�g�����̗p
				isDir = true;
				traceW(L"detect directory/3");

				fileInfo = dirInfoList[0]->FileInfo;
			}
		}
	}

	if (!isDir && !isFile)
	{
		traceW(L"not found");

		return STATUS_OBJECT_NAME_NOT_FOUND;
	}

	*pFileInfo = fileInfo;

	return STATUS_SUCCESS;
}

// EOF