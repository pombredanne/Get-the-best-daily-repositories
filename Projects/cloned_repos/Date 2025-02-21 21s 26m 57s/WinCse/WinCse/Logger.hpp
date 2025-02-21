#pragma once

#include <string>
#include <fstream>

class Logger : public ILogger
{
private:
	const std::wstring mTempDir;

	// ���O�o�̓f�B���N�g�� (�v���O�������� "-T")
	std::wstring mTraceLogDir;
	bool mTraceLogEnabled = false;

	// ���O�p�t�@�C�� (�X���b�h�E���[�J��)
	static thread_local std::wofstream mTLFile;
	static thread_local bool mTLFileOK;
	static thread_local uint64_t mTLFlushTime;

protected:
	void traceW_write(const SYSTEMTIME* st, const wchar_t* buf) const;

public:
	Logger(const wchar_t* tmpdir) : mTempDir(tmpdir) { }
	bool SetOutputDir(const wchar_t* path);

	// ���O�o��
	void traceA_impl(const int indent, const char*, const int, const char*, const char* format, ...) override;
	void traceW_impl(const int indent, const wchar_t*, const int, const wchar_t*, const wchar_t* format, ...) override;
};

// EOF