#include "WinCseLib.h"
#include <sddl.h>
#include <sstream>
#include <iomanip>
#include <cwctype>
#include <chrono>
#include <filesystem>
#include <fstream>

//
// �قƂ�� Copilot �ɍl���Ă������
//
bool touchIfNotExists(const std::wstring& arg)
{
	if (!std::filesystem::exists(arg))
	{
		// ��t�@�C���̍쐬
		std::wofstream ofs(arg);
		if (!ofs)
		{
			return false;
		}

		ofs.close();
	}

	if (std::filesystem::exists(arg))
	{
		// �t�@�C���ł͂Ȃ�
		if (!std::filesystem::is_regular_file(arg))
		{
			return false;
		}
	}
	else
	{
		// ���݂��Ȃ�
		return false;
	}

	return true;
}

bool mkdirIfNotExists(const std::wstring& arg)
{
	if (std::filesystem::exists(arg))
	{
		if (!std::filesystem::is_directory(arg))
		{
			return false;
		}
	}
	else
	{
		std::error_code ec;
		if (!std::filesystem::create_directories(arg, ec))
		{
			return false;
		}
	}

	// �������݃e�X�g
	const auto tmpfile{ _wtempnam(arg.c_str(), L"wtest") };
	APP_ASSERT(tmpfile);

	std::ofstream ofs(tmpfile);
	if (!ofs)
	{
		return false;
	}

	ofs.close();

	std::error_code ec;
	std::filesystem::remove(tmpfile, ec);
	free(tmpfile);

	return true;
}

std::string Base64EncodeA(const std::string& data)
{
	DWORD encodedSize = 0;
	BOOL b = ::CryptBinaryToStringA(reinterpret_cast<const BYTE*>(data.c_str()), (DWORD)data.size(), CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF, NULL, &encodedSize);
	APP_ASSERT(b);

	std::vector<char> encodedData(encodedSize);
	b = ::CryptBinaryToStringA(reinterpret_cast<const BYTE*>(data.c_str()), (DWORD)data.size(), CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF, encodedData.data(), &encodedSize);
	APP_ASSERT(b);

	return std::string(encodedData.begin(), encodedData.end() - 1);
}

std::string Base64DecodeA(const std::string& encodedData)
{
	DWORD decodedSize = 0;
	BOOL b = ::CryptStringToBinaryA(encodedData.c_str(), (DWORD)encodedData.size(), CRYPT_STRING_BASE64, NULL, &decodedSize, NULL, NULL);
	APP_ASSERT(b);

	std::vector<BYTE> decodedData(decodedSize);
	b = ::CryptStringToBinaryA(encodedData.c_str(), (DWORD)encodedData.size(), CRYPT_STRING_BASE64, decodedData.data(), &decodedSize, NULL, NULL);
	APP_ASSERT(b);

	return std::string(decodedData.begin(), decodedData.end());
}

std::string URLEncodeA(const std::string& str)
{
	std::ostringstream encoded;
	for (char ch : str)
	{
		if (isalnum(static_cast<unsigned char>(ch)) || ch == '-' || ch == '_' || ch == '.' || ch == '~')
		{
			encoded << ch;
		}
		else
		{
			encoded << '%' << std::uppercase << std::hex << std::setw(2) << std::setfill('0') << (int)(unsigned char)ch;
		}
	}
	return encoded.str();
}

std::string URLDecodeA(const std::string& str)
{
	std::ostringstream decoded;

	for (size_t i = 0; i < str.size(); ++i)
	{
		if (str[i] == '%' && i + 2 < str.size())
		{
			int value;

			std::istringstream iss(str.substr(i + 1, 2));
			if (iss >> std::hex >> value)
			{
				decoded << static_cast<char>(value);
				i += 2;
			}
			else
			{
				decoded << str[i];
			}
		}
		else if (str[i] == '+')
		{
			decoded << ' ';
		}
		else
		{
			decoded << str[i];
		}
	}

	return decoded.str();
}

std::string EncodeFileNameToLocalNameA(const std::string& str)
{
	return URLEncodeA(Base64EncodeA(str));
}

std::string DecodeLocalNameToFileNameA(const std::string& str)
{
	return Base64DecodeA(URLDecodeA(str));
}

std::wstring EncodeFileNameToLocalNameW(const std::wstring& str)
{
	return MB2WC(URLEncodeA(Base64EncodeA(WC2MB(str))));
}

std::wstring DecodeLocalNameToFileNameW(const std::wstring& str)
{
	return MB2WC(Base64DecodeA(URLDecodeA(WC2MB(str))));
}

bool GetIniStringW(const std::wstring& confPath, const wchar_t* argSection, const wchar_t* keyName, std::wstring* pValue)
{
	APP_ASSERT(argSection);
	APP_ASSERT(argSection[0]);

	std::vector<wchar_t> buf(BUFSIZ);

	::SetLastError(ERROR_SUCCESS);
	::GetPrivateProfileStringW(argSection, keyName, L"", buf.data(), (DWORD)buf.size(), confPath.c_str());

	if (::GetLastError() != ERROR_SUCCESS)
	{
		return false;
	}

	*pValue = std::wstring(buf.data());

	return true;
}

bool GetIniStringA(const std::string& confPath, const char* argSection, const char* keyName, std::string* pValue)
{
	APP_ASSERT(argSection);
	APP_ASSERT(argSection[0]);

	std::vector<char> buf(BUFSIZ);

	::SetLastError(ERROR_SUCCESS);
	::GetPrivateProfileStringA(argSection, keyName, "", buf.data(), (DWORD)buf.size(), confPath.c_str());

	if (::GetLastError() != ERROR_SUCCESS)
	{
		return false;
	}

	*pValue = std::string(buf.data());

	return true;
}

// �O��̋󔒂��g��������֐�
std::wstring TrimW(const std::wstring& str)
{
	std::wstring trimmedStr = str;

	// �擪�̋󔒂��g����
	trimmedStr.erase(trimmedStr.begin(), std::find_if(trimmedStr.begin(), trimmedStr.end(), [](wchar_t ch) {
		return !std::isspace(ch);
	}));

	// �����̋󔒂��g����
	trimmedStr.erase(std::find_if(trimmedStr.rbegin(), trimmedStr.rend(), [](wchar_t ch) {
		return !std::isspace(ch);
	}).base(), trimmedStr.end());

	return trimmedStr;
}

std::string TrimA(const std::string& str)
{
	return WC2MB(TrimW(MB2WC(str)));
}

std::wstring WildcardToRegexW(const std::wstring& wildcard)
{
	std::wstringstream ss;

	ss << L'^';

	for (wchar_t ch : wildcard)
	{
		if (ch == L'\0')
		{
			break;
		}

		switch (ch)
		{
			case L'*':
				ss << L".*";
				break;

			case L'?':
				ss << L'.';
				break;

			default:
				if (std::iswpunct(ch))
				{
					ss << L'\\';
				}
				ss << ch;
				break;
		}
	}

	ss << L'$';

	return ss.str();
}

std::string WildcardToRegexA(const std::string& arg)
{
	return WC2MB(WildcardToRegexW(MB2WC(arg)));
}

uint64_t STCTimeToUTCMilliSecW(const std::wstring& path)
{
	APP_ASSERT(!path.empty());

	//
	struct _stat st;
	if (_wstat(path.c_str(), &st) != 0)
	{
		return 0;
	}

	// time_t �� time_point �ɕϊ�
	const auto time_point = std::chrono::system_clock::from_time_t(st.st_ctime);

	// �G�|�b�N����̌o�ߎ��Ԃ��~���b�P�ʂŎ擾
	auto duration = time_point.time_since_epoch();

	return std::chrono::duration_cast<std::chrono::milliseconds>(duration).count();
}

uint64_t STCTimeToUTCMilliSecA(const std::string& path)
{
	return STCTimeToUTCMilliSecW(MB2WC(path));
}

uint64_t STCTimeToWinFileTimeW(const std::wstring& path)
{
	return UtcMillisToWinFileTime(STCTimeToUTCMilliSecW(path));
}

uint64_t STCTimeToWinFileTimeA(const std::string& path)
{
	return UtcMillisToWinFileTime(STCTimeToUTCMilliSecA(path));
}

// wstring ���� string �ւ̕ϊ�
//#define CNV_CODEPAGE		(CP_ACP)
#define CNV_CODEPAGE		(CP_UTF8)

std::string WC2MB(const std::wstring& wstr)
{
	if (wstr.empty())
	{
		return "";
	}

	const wchar_t* pWstr = wstr.c_str();

	::SetLastError(ERROR_SUCCESS);
	const int need = ::WideCharToMultiByte(CNV_CODEPAGE, 0, pWstr, -1, NULL, 0, NULL, NULL);
	APP_ASSERT(::GetLastError() == ERROR_SUCCESS);

	std::vector<char> buff(need);
	char* pStr = buff.data();

	::WideCharToMultiByte(CNV_CODEPAGE, 0, pWstr, -1, pStr, need, NULL, NULL);
	APP_ASSERT(::GetLastError() == ERROR_SUCCESS);

	return std::string{ pStr };
}

// string ���� wstring �ւ̕ϊ�
std::wstring MB2WC(const std::string& str)
{
	if (str.empty())
	{
		return L"";
	}

	const char* pStr = str.c_str();

	::SetLastError(ERROR_SUCCESS);
	const int need = ::MultiByteToWideChar(CNV_CODEPAGE, 0, pStr, -1, NULL, 0);
	APP_ASSERT(::GetLastError() == ERROR_SUCCESS);

	std::vector<wchar_t> buff(need);
	wchar_t* pWstr = buff.data();

	::MultiByteToWideChar(CNV_CODEPAGE, 0, pStr, -1, pWstr, need);
	APP_ASSERT(::GetLastError() == ERROR_SUCCESS);

	return std::wstring{ pWstr };
}

// UTC�̃~���b�� Windows �̃t�@�C�������ɕϊ�������@
uint64_t UtcMillisToWinFileTime(uint64_t utcMilliseconds)
{
	// 1601�N1��1������̃I�t�Z�b�g
	static const uint64_t EPOCH_DIFFERENCE = 11644473600000LL; // �~���b

	// �~���b��100�i�m�b�P�ʂɕϊ����A�I�t�Z�b�g�����Z
	static const uint64_t HUNDRED_NANOSECONDS_PER_MILLISECOND = 10000;

	return (utcMilliseconds + EPOCH_DIFFERENCE) * HUNDRED_NANOSECONDS_PER_MILLISECOND;
}

// Windows �̃t�@�C�������� UTC �̃~���b�ɕϊ�������@
uint64_t WinFileTimeToUtcMillis(const FILETIME &ft)
{
	// FILETIME �� 64 �r�b�g�̐����ɕϊ�
	ULARGE_INTEGER ull = {};

	ull.LowPart = ft.dwLowDateTime;
	ull.HighPart = ft.dwHighDateTime;

	// 1601 �N 1 �� 1 ������̌o�ߎ��Ԃ� 100 �i�m�b�P�ʂŕێ����Ă��邽�߁A1970 �N 1 �� 1 ���Ƃ̍����v�Z
	static const uint64_t UNIX_EPOCH_DIFFERENCE = 116444736000000000ULL;

	// ���������A�~���b�P�ʂɕϊ�
	return (ull.QuadPart - UNIX_EPOCH_DIFFERENCE) / 10000ULL;
}

long long int TimePointToUtcSeconds(const std::chrono::system_clock::time_point& tp)
{
	// �G�|�b�N����̌o�ߎ��Ԃ��~���b�P�ʂŎ擾
	auto duration = tp.time_since_epoch();

	// �~���b�P�ʂ�Unix���Ԃɕϊ�
	//auto millis = std::chrono::duration_cast<std::chrono::milliseconds>(duration).count();

	// �b�P�ʂ�Unix���Ԃɕϊ�
	auto seconds = std::chrono::duration_cast<std::chrono::seconds>(duration).count();

	return seconds;
}

uint64_t GetCurrentUtcMillis()
{
	FILETIME ft;
	GetSystemTimeAsFileTime(&ft);

	return WinFileTimeToUtcMillis(ft);
}

// ������̃n�b�V���l���Z�o
size_t HashString(const std::wstring& arg)
{
	static std::hash<std::wstring> hashStr;

	return hashStr(arg);
}

//
// �t�@�C���E�n���h������t�@�C���E�p�X�ɕϊ�
bool HandleToPath(HANDLE Handle, std::wstring& ref)
{
	::SetLastError(ERROR_SUCCESS);

	const auto needLen = ::GetFinalPathNameByHandle(Handle, nullptr, 0, FILE_NAME_NORMALIZED);
	APP_ASSERT(::GetLastError() == ERROR_NOT_ENOUGH_MEMORY);

	const auto needSize = needLen + 1;
	std::wstring path(needSize, 0);

	::GetFinalPathNameByHandle(Handle, path.data(), needSize, FILE_NAME_NORMALIZED);
	APP_ASSERT(::GetLastError() == ERROR_SUCCESS);

	ref = std::move(path);

	return true;
}

// SDDL ������֘A
static const SECURITY_INFORMATION DEFAULT_SECURITY_INFO = OWNER_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION;

static LPWSTR SDToSDStr_(PSECURITY_DESCRIPTOR pSecDesc)
{
	LPWSTR pStringSD = nullptr;

	// �Z�L�����e�B�L�q�q�𕶎���ɕϊ�
	if (::ConvertSecurityDescriptorToStringSecurityDescriptorW(
		pSecDesc,
		SDDL_REVISION_1,
		DEFAULT_SECURITY_INFO,
		&pStringSD,
		nullptr))
	{
		return pStringSD;
	}

	return nullptr;
}

static LPWSTR HandleToSDStr_(HANDLE Handle)
{
	APP_ASSERT(Handle != INVALID_HANDLE_VALUE);

	SECURITY_DESCRIPTOR secDesc = {};
	DWORD lengthNeeded = 0;

	PSECURITY_DESCRIPTOR pSecDesc = nullptr;
	LPWSTR pStringSD = nullptr;

	// �ŏ��̌Ăяo���ŕK�v�ȃo�b�t�@�T�C�Y���擾
	BOOL result = ::GetKernelObjectSecurity(Handle, DEFAULT_SECURITY_INFO, &secDesc, 0, &lengthNeeded);

	if (!result && ::GetLastError() == ERROR_INSUFFICIENT_BUFFER)
	{
		// �K�v�ȃo�b�t�@�T�C�Y�����o�b�t�@���m��
		pSecDesc = (PSECURITY_DESCRIPTOR)::LocalAlloc(LPTR, lengthNeeded);
		if (pSecDesc)
		{
			// �ēx�Ăяo���ăZ�L�����e�B�����擾
			result = ::GetKernelObjectSecurity(Handle, DEFAULT_SECURITY_INFO, pSecDesc, lengthNeeded, &lengthNeeded);
			if (result)
			{
				pStringSD = SDToSDStr_(pSecDesc);
			}

			goto success;
		}
	}

	if (pStringSD)
	{
		::LocalFree(pStringSD);
		pStringSD = nullptr;
	}

success:
	if (pSecDesc)
	{
		::LocalFree(pSecDesc);
		pSecDesc = nullptr;
	}

	return pStringSD;
}

static LPWSTR PathToSDStr_(LPCWSTR Path)
{
	APP_ASSERT(Path);

	LPWSTR pStringSD = nullptr;

	HANDLE Handle = ::CreateFileW(Path,
		FILE_READ_ATTRIBUTES | READ_CONTROL, 0, 0,
		OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, 0);

	if (INVALID_HANDLE_VALUE != Handle)
	{
		pStringSD = HandleToSDStr_(Handle);

		::CloseHandle(Handle);
		Handle = INVALID_HANDLE_VALUE;
	}

	return pStringSD;
}

bool PathToSDStr(const std::wstring& path, std::wstring& sdstr)
{
	const auto p = PathToSDStr_(path.c_str());
	if (!p)
	{
		return false;
	}

	sdstr = p;
	LocalFree(p);

	return true;
}

//
// LogBlock
//
thread_local int LogBlock::mDepth = 0;

LogBlock::LogBlock(const wchar_t* argFile, const int argLine, const wchar_t* argFunc)
	: file(argFile), line(argLine), func(argFunc)
{
	mCounter++;

	start = std::chrono::steady_clock::now();
	GetLogger()->traceW_impl(mDepth, file, line, func, L"{enter}");
	mDepth++;
}

LogBlock::~LogBlock()
{
	const auto end{ std::chrono::steady_clock::now() };
	const auto duration{ std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count() };

	mDepth--;
	GetLogger()->traceW_impl(mDepth, file, -1, func, L"{leave} (%lld ms)", duration);
}

//
// BucketKey
//

// ��������o�P�b�g���ƃL�[�ɕ���
BucketKey::BucketKey(const wchar_t* arg)
{
	std::wstring str{ arg };

	std::vector<std::wstring> tokens;
	std::wistringstream stream(str);
	std::wstring token;

	while (std::getline(stream, token, L'\\'))
	{
		tokens.push_back(token);
	}

	switch (tokens.size())
	{
		case 0:
		case 1:
		{
			return;
		}
		case 2:
		{
			bucket = std::move(tokens[1]);
			break;
		}
		default:
		{
			bucket = std::move(tokens[1]);

			std::wostringstream ss;
			for (int i = 2; i < tokens.size(); ++i)
			{
				if (i != 2)
				{
					ss << L'/';
				}
				ss << std::move(tokens[i]);
			}

			key = ss.str();
			HasKey = true;

			break;
		}
	}

	OK = true;
}

// EOF
