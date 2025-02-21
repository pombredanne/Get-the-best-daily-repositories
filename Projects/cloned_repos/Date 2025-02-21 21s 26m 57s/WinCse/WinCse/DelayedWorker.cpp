#include "WinCseLib.h"
#include "DelayedWorker.hpp"
#include <filesystem>
#include <mutex>
#include <sstream>


#define ENABLE_TASK		(1)


#if ENABLE_TASK
// �^�X�N�������L��
const int WORKER_MAX = 2;

#else
// �^�X�N����������
const int WORKER_MAX = 0;

#endif

DelayedWorker::DelayedWorker(const wchar_t* tmpdir, const wchar_t* iniSection)
	: mTempDir(tmpdir), mIniSection(iniSection)
{
	// OnSvcStart �̌Ăяo�����ɂ��C�x���g�I�u�W�F�N�g��������
	// ������邽�߁A�R���X�g���N�^�Ő������� OnSvcStart �� null �`�F�b�N����

	mEvent = ::CreateEvent(NULL, FALSE, FALSE, NULL);
}

DelayedWorker::~DelayedWorker()
{
	NEW_LOG_BLOCK();

	if (mEvent)
	{
		traceW(L"close event");
		::CloseHandle(mEvent);
	}
}

bool DelayedWorker::OnSvcStart(const wchar_t* argWorkDir)
{
	NEW_LOG_BLOCK();
	APP_ASSERT(argWorkDir);

	if (!mEvent)
	{
		traceW(L"mEvent is null");
		return false;
	}

	for (int i=0; i<WORKER_MAX; i++)
	{
		mThreads.emplace_back(&DelayedWorker::listenEvent, this, i);
	}

	return true;
}

struct BreakLoopRequest : public std::exception
{
	BreakLoopRequest(char const* const msg) : std::exception(msg) { }
};

struct BreakLoopTask : public ITask
{
	void run(CALLER_ARG IWorker* worker, const int indent) override
	{
		GetLogger()->traceW_impl(indent, __FUNCTIONW__, __LINE__, __FUNCTIONW__, L"throw break");

		throw BreakLoopRequest("from " __FUNCTION__);
	}
};

void DelayedWorker::OnSvcStop()
{
	NEW_LOG_BLOCK();

	traceW(L"wait for thread end ...");

	for (int i=0; i<mThreads.size(); i++)
	{
		// �ŗD��̒�~����
		addTask(new BreakLoopTask, CanIgnore::NO, Priority::HIGH);
	}

	for (auto& thr: mThreads)
	{
		thr.join();
	}

	traceW(L"done.");
}

void DelayedWorker::listenEvent(const int i)
{
	NEW_LOG_BLOCK();

	while (1)
	{
		try
		{
			traceW(L"(%d): wait for signal ...", i);
			const auto reason = ::WaitForSingleObject(mEvent, INFINITE);

			switch (reason)
			{
				case WAIT_TIMEOUT:
				{
					APP_ASSERT(0);

					break;
				}

				case WAIT_OBJECT_0:
				{
					traceW(L"(%d): wait for signal: catch signal", i);
					break;
				}

				default:
				{
					traceW(L"(%d): wait for signal: error code=%ld, continue", i, reason);
					throw std::runtime_error("illegal route");

					break;
				}
			}

			// �L���[�ɓ����Ă���^�X�N������
			while (1)
			{
				auto task{ dequeueTask() };
				if (!task)
				{
					traceW(L"(%d): no more oneshot-tasks", i);
					break;
				}

				traceW(L"(%d): run oneshot task ...", i);
				task->_mWorkerId_4debug = i;
				task->run(INIT_CALLER this, LOG_DEPTH());
				traceW(L"(%d): run oneshot task done", i);

				// �������邲�Ƃɑ��̃X���b�h�ɉ�
				//::SwitchToThread();
			}
		}
		catch (const BreakLoopRequest&)
		{
			traceW(L"(%d): catch loop-break request, go exit thread", i);
			break;
		}
		catch (const std::runtime_error& err)
		{
			traceW(L"(%d): what: %s", i, err.what());
			break;
		}
		catch (...)
		{
			traceW(L"(%d): unknown error, continue", i);
		}
	}

	traceW(L"(%d): exit event loop", i);
}

std::wstring ITask::synonymString()
{
	static std::atomic<int> aint(0);

	std::wstringstream ss;

	ss << MB2WC(typeid(*this).name());
	ss << L"; ";
	ss << aint++;

	return ss.str();
}

static std::mutex gGuard;

#define THREAD_SAFE() \
    std::lock_guard<std::mutex> lock_(gGuard)


bool DelayedWorker::addTask(ITask* argTask, CanIgnore ignState, Priority priority)
{
	THREAD_SAFE();
	NEW_LOG_BLOCK();
	APP_ASSERT(argTask)

	bool add = false;

#if ENABLE_TASK
	argTask->mPriority = priority;

	if (priority == Priority::HIGH)
	{
		// �D�悷��ꍇ�͐擪�ɒǉ�

		mTaskQueue.emplace_front(argTask);

		add = true;
	}
	else
	{
		// �ʏ�͌���ɒǉ�
		const auto argTaskName{ argTask->synonymString() };

		if (ignState == CanIgnore::YES)
		{
			// �����\
			const auto it = std::find_if(mTaskQueue.begin(), mTaskQueue.end(), [&argTaskName](const auto& task)
			{
				// �L���[���瓯���V�m�j����T��
				return task->synonymString() == argTaskName;
			});

			if (it == mTaskQueue.end())
			{
				// �����̂��̂����݂��Ȃ�
				add = true;
			}
		}
		else
		{
			// �����ł��Ȃ�
			add = true;
		}

		if (add)
		{
			// ����ɒǉ�
			mTaskQueue.emplace_back(argTask);

			traceW(L"[%s]: task added", argTaskName.c_str());
		}
		else
		{
			delete argTask;

			traceW(L"[%s]: task ignored", argTaskName.c_str());
		}
	}

	// WaitForSingleObject() �ɒʒm
	::SetEvent(mEvent);

#else
	// ���[�J�[�����������ȏꍇ�́A�^�X�N�̃��N�G�X�g�𖳎�
	delete argTask;

#endif

	return add;
}

std::shared_ptr<ITask> DelayedWorker::dequeueTask()
{
	THREAD_SAFE();
	//NEW_LOG_BLOCK();

#if ENABLE_TASK
	if (!mTaskQueue.empty())
	{
		auto ret{ mTaskQueue.front() };
		mTaskQueue.pop_front();

		return ret;
	}

#else
	// ���[�J�[�����������ȏꍇ�́Anull ��ԋp

#endif

	return nullptr;
}

// EOF