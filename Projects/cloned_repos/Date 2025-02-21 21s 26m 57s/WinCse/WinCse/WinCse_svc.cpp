#include "WinCseLib.h"
#include "WinCse.hpp"
#include <filesystem>
#include <iostream>


static const wchar_t* CONFIGFILE_FNAME = L"WinCse.conf";
static const wchar_t* FILE_REFERENCE_FNAME = L"reference.file";
static const wchar_t* DIR_REFERENCE_FNAME = L"reference.dir";


//
// �v���O�������� "-u" ����Z�o���ꂽ�f�B���N�g������ ini �t�@�C����ǂ�
// S3 �N���C�A���g�𐶐�����
//
bool WinCse::OnSvcStart(const wchar_t* argWorkDir)
{
	NEW_LOG_BLOCK();
	APP_ASSERT(argWorkDir);

	namespace fs = std::filesystem;

	APP_ASSERT(fs::exists(argWorkDir));
	APP_ASSERT(fs::is_directory(argWorkDir));

	bool ret = false;

	try
	{
		// move ����̂Ŕ� const
		std::wstring workDir{ fs::weakly_canonical(fs::path(argWorkDir)).wstring() };

		//
		// ini �t�@�C������l���擾
		//
		const std::wstring confPath{ workDir + L'\\' + CONFIGFILE_FNAME };

		traceW(L"Detect credentials file path is %s", confPath.c_str());

		const std::wstring iniSectionStr{ mIniSection };
		const auto iniSection = iniSectionStr.c_str();

		//
		// �ő�t�@�C���T�C�Y(MB)
		//
		const int maxFileSize = (int)::GetPrivateProfileIntW(iniSection, L"max_filesize_mb", 4, confPath.c_str());

		//
		// �����Q�Ɨp�t�@�C��/�f�B���N�g���̏���
		//
		const std::wstring fileRefPath{ mTempDir + L'\\' + FILE_REFERENCE_FNAME };
		if (!touchIfNotExists(fileRefPath))
		{
			traceW(L"file not exists: %s", fileRefPath.c_str());
			return false;
		}

		const std::wstring dirRefPath{ mTempDir + L'\\' + DIR_REFERENCE_FNAME };
		if (!mkdirIfNotExists(dirRefPath))
		{
			traceW(L"dir not exists: %s", dirRefPath.c_str());
			return false;
		}

		//
		// �����Q�Ɨp�t�@�C��/�f�B���N�g�����J��
		//
		mFileRefHandle = ::CreateFileW(fileRefPath.c_str(),
			FILE_READ_ATTRIBUTES | READ_CONTROL, 0, 0,
			OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, 0);
		if (INVALID_HANDLE_VALUE == mFileRefHandle)
		{
			traceW(L"file open error: %s", fileRefPath.c_str());
			return false;
		}

		mDirRefHandle = ::CreateFileW(dirRefPath.c_str(),
			FILE_READ_ATTRIBUTES | READ_CONTROL, 0, 0,
			OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, 0);
		if (INVALID_HANDLE_VALUE == mDirRefHandle)
		{
			traceW(L"file open error: %s", dirRefPath.c_str());
			return false;
		}

		mMaxFileSize = maxFileSize;
		mWorkDir = std::move(workDir);

		traceW(L"INFO: TempDir=%s, WorkDir=%s, DirRef=%s, FileRef=%s",
			mTempDir.c_str(), mWorkDir.c_str(), dirRefPath.c_str(), fileRefPath.c_str());

		IService* services[] = { mDelayedWorker, mIdleWorker, mStorage };

		// OnSvcStart() �̓`�d
		for (int i=0; i<_countof(services); i++)
		{
			const auto service = services[i];
			const auto className = getDerivedClassNames(service);

			traceA("%s::OnSvcStart()", className.c_str());

			if (!services[i]->OnSvcStart(argWorkDir))
			{
				traceA("fault: OnSvcStart()");
				return false;
			}
		}

		// OnPostSvcStart() �̓`�d
		for (int i=0; i<_countof(services); i++)
		{
			const auto service = services[i];
			const auto className = getDerivedClassNames(service);

			traceA("%s::OnPostSvcStart()", className.c_str());

			if (!services[i]->OnPostSvcStart())
			{
				traceA("fault: OnPostSvcStart()");
				return false;
			}
		}

		ret = true;
	}
	catch (const std::runtime_error& err)
	{
		std::cerr << "what: " << err.what() << std::endl;
	}
	catch (...)
	{
		std::cerr << "unknown error" << std::endl;
	}

	return ret;		// ��O�������� false
}

void WinCse::OnSvcStop()
{
	NEW_LOG_BLOCK();

	// ���[�J�[�E�X���b�h�̒�~
	mDelayedWorker->OnSvcStop();
	mIdleWorker->OnSvcStop();

	// �X�g���[�W�̏I��
	mStorage->OnSvcStop();
}

void WinCse::UpdateVolumeParams(FSP_FSCTL_VOLUME_PARAMS* VolumeParams)
{
	NEW_LOG_BLOCK();
	APP_ASSERT(VolumeParams);

	mStorage->updateVolumeParams(VolumeParams);
}

// EOF
