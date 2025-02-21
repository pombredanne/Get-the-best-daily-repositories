#include "WinCseLib.h"
#include "Logger.hpp"
#include <filesystem>
#include <sstream>
#include <iostream>

#undef traceW
#undef traceA

//
// Logger
//
thread_local std::wofstream Logger::mTLFile;
thread_local bool Logger::mTLFileOK = true;
thread_local uint64_t Logger::mTLFlushTime = 0;

// �f�o�b�O�p���O�o��

static const wchar_t* ALTERNATIVE_LOGDIR_FNAME = L"aws-s3\\log";

#define FORMAT_DT	"%02d:%02d:%02d.%03d"
#define FORMAT_ERR	"%-3lu"
#define FORMAT_SRC	"%-32s"
#define FORMAT_FUNC	"%-36s"

#define FORMAT1		FORMAT_DT "\t" FORMAT_ERR "\t" FORMAT_SRC "\t" FORMAT_FUNC "\t"
#define FORMAT2		"\n"


void Logger::traceW_impl(const int indent, const wchar_t* fullPath, const int line, const wchar_t* func, const wchar_t* format, ...)
{
#ifdef _RELEASE
	if (!mTraceLogEnabled)
		return;
#endif

	APP_ASSERT(indent >= 0);

	const auto err = ::GetLastError();
	const auto callFromFile(std::filesystem::path(fullPath).filename().wstring());
	const wchar_t* file = callFromFile.c_str();

	SYSTEMTIME st;
	::GetLocalTime(&st);

	std::wstringstream ss;
	ss << file << L'(' << line << L')';
	const auto src{ ss.str() };

	va_list args;
	va_start(args, format);

	size_t bufsiz = 1;	// terminate
	bufsiz += swprintf(nullptr, 0, L"" FORMAT1, st.wHour, st.wMinute, st.wSecond, st.wMilliseconds, err, src.c_str(), func);
	bufsiz += indent;
	bufsiz += vswprintf(nullptr, 0, format, args);
	bufsiz += wcslen(L"" FORMAT2);

	std::vector<wchar_t> vbuf(bufsiz);
	wchar_t* buf = vbuf.data();

	auto remain = bufsiz;
	remain -= swprintf(&buf[bufsiz - remain], remain, L"" FORMAT1, st.wHour, st.wMinute, st.wSecond, st.wMilliseconds, err, src.c_str(), func);

	wchar_t* pos = &buf[bufsiz - remain];
	for (int i = 0; i < indent; i++, pos++)
	{
		*pos = L'\t';

	}
	remain -= indent;

	remain -= vswprintf(&buf[bufsiz - remain], remain, format, args);
	remain -= swprintf(&buf[bufsiz - remain], remain, L"" FORMAT2);
	APP_ASSERT(remain == 1);

	va_end(args);

	traceW_write(&st, buf);
}

void Logger::traceA_impl(const int indent, const char* fullPath, const int line, const char* func, const char* format, ...)
{
#ifdef _RELEASE
	if (!mTraceLogEnabled)
		return;
#endif

	APP_ASSERT(indent >= 0);

	const auto err = ::GetLastError();
	const auto callFromFile(std::filesystem::path(fullPath).filename().string());
	const char* file = callFromFile.c_str();

	SYSTEMTIME st;
	::GetLocalTime(&st);

	std::stringstream ss;
	ss << file << '(' << line << ')';
	const auto src{ ss.str() };

	va_list args;
	va_start(args, format);

	size_t bufsiz = 1;	// terminate
	bufsiz += snprintf(nullptr, 0, FORMAT1, st.wHour, st.wMinute, st.wSecond, st.wMilliseconds, err, src.c_str(), func);
	bufsiz += indent;
	bufsiz += vsnprintf(nullptr, 0, format, args);
	bufsiz += strlen(FORMAT2);

	std::vector<char> vbuf(bufsiz);
	char* buf = vbuf.data();

	auto remain = bufsiz;
	remain -= snprintf(&buf[bufsiz - remain], remain, FORMAT1, st.wHour, st.wMinute, st.wSecond, st.wMilliseconds, err, src.c_str(), func);

	char* pos = &buf[bufsiz - remain];
	for (int i = 0; i < indent; i++, pos++)
	{
		*pos = '\t';

	}
	remain -= indent;

	remain -= vsnprintf(&buf[bufsiz - remain], remain, format, args);
	remain -= snprintf(&buf[bufsiz - remain], remain, FORMAT2);
	APP_ASSERT(remain == 1);

	va_end(args);

	traceW_write(&st, MB2WC(buf).c_str());
}

void Logger::traceW_write(const SYSTEMTIME* st, const wchar_t* buf) const
{
	const auto pid = ::GetCurrentProcessId();
	const auto tid = ::GetCurrentThreadId();

	{
		std::wstringstream ss;

		ss << L"| ";
		ss << std::setw(3) << (tid % 1000);
		ss << L' ' << buf;

		::OutputDebugString(ss.str().c_str());
	}

	if (!mTraceLogEnabled)
		return;

	//
	// mLog.TLFile �̓X���b�h�E���[�J���Ȃ̂ŁA���s���ꂽ�X���b�h���Ƃ�
	// ���O�t�@�C�����쐬����A�����ɏo�͂��s���邽�ߔr������͕s�v
	//
	if (mTLFileOK)
	{
		if (!mTLFile.is_open())
		{
			std::wstringstream ss;

#ifdef _DEBUG
			ss << mTraceLogDir << L"\\trace-";

#else
			ss << mTraceLogDir << L"\\WinCse-trace-";
			ss << std::setw(4) << std::setfill(L'0') << st->wYear;
			ss << std::setw(2) << std::setfill(L'0') << st->wMonth;
			ss << std::setw(2) << std::setfill(L'0') << st->wDay;
			ss << L'-';
			ss << std::setw(2) << std::setfill(L'0') << st->wHour;
			ss << std::setw(2) << std::setfill(L'0') << st->wMinute;
			ss << std::setw(2) << std::setfill(L'0') << st->wSecond;
			ss << L'-';
#endif

			ss << pid << L'-' << tid << L".log";
			const std::wstring path = ss.str();

#ifdef _RELEASE
			std::wcout << L"Open trace log file: " << path << std::endl;
#endif
			// ������Ȃ��Ɠ��{�ꂪ�o�͂ł��Ȃ�
			mTLFile.imbue(std::locale("", LC_ALL));

			mTLFile.open(path, std::ios_base::app);
			::SetLastError(ERROR_SUCCESS);

			if (!mTLFile)
			{
				// �J���Ȃ�������ȍ~�͎��݂Ȃ�

				std::wcerr << L"errno: " << errno << std::endl;

				mTLFileOK = false;
				return;
			}

			mTLFlushTime = GetCurrentUtcMillis();
		}
	}

	if (mTLFile)
	{
		mTLFile << buf;

#ifdef _DEBUG
		// �f�o�b�O�ɕs�ւȂ̂ŕ��Ă��܂�
		mTLFile.close();

#else
		const auto now{ GetCurrentUtcMillis() };

		if (now - mTLFlushTime > (60ULL * 1 * 1000))
		{
			// 1 ���Ɉ�x���x�� flush ����

			mTLFile.flush();

			mTLFlushTime = now;
		}
#endif
	}
}

//
// �v���O�������� "-T" �Ŏw�肳�ꂽ�f�B���N�g�������O�o�͗p�ɕۑ�����
//
bool Logger::SetOutputDir(const wchar_t* argPath)
{
	namespace fs = std::filesystem;

	if (argPath)
	{
		const auto trcDir{ fs::weakly_canonical(fs::path(argPath)) };

		if (fs::exists(trcDir) && fs::is_directory(trcDir))
		{
			mTraceLogDir = trcDir.wstring();
			mTraceLogEnabled = true;

			return true;
		}

		// �w�肳�ꂽ�f�B���N�g�������p�ł��Ȃ��Ƃ��́A��ւƂ��ăV�X�e���̃e���|�����ɏo��

		auto altTrcDir{ mTempDir + L'\\' + ALTERNATIVE_LOGDIR_FNAME };

		if (!mkdirIfNotExists(altTrcDir))
		{
			return false;
		}

		mTraceLogDir = std::move(altTrcDir);
		mTraceLogEnabled = true;

		return false;
	}

	return true;
}

// EOF