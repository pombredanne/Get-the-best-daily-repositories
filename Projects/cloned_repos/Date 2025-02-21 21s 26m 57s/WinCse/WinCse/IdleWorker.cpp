#include "WinCseLib.h"
#include "IdleWorker.hpp"
#include <filesystem>
#include <mutex>
#include <numeric>

#define ENABLE_TASK		(1)

const int WORKER_MAX = 1;


IdleWorker::IdleWorker(const wchar_t* tmpdir, const wchar_t* iniSection)
	: mTempDir(tmpdir), mIniSection(iniSection)
{
	// OnSvcStart �̌Ăяo�����ɂ��C�x���g�I�u�W�F�N�g��������
	// ������邽�߁A�R���X�g���N�^�Ő������� OnSvcStart �� null �`�F�b�N����

	mEvent = ::CreateEvent(NULL, FALSE, FALSE, NULL);
}

IdleWorker::~IdleWorker()
{
	NEW_LOG_BLOCK();

	if (mEvent)
	{
		traceW(L"close event");
		::CloseHandle(mEvent);
	}
}

bool IdleWorker::OnSvcStart(const wchar_t* argWorkDir)
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
		mThreads.emplace_back(&IdleWorker::listenEvent, this, i);
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

void IdleWorker::OnSvcStop()
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

void IdleWorker::listenEvent(const int i)
{
	NEW_LOG_BLOCK();

	namespace chrono = std::chrono;

	//
	// ���O�̋L�^�񐔂͏󋵂ɂ���ĕω����邽�߁A�J�n�����萔��
	// �L�^�񐔂��̎悵�A��������Z�o������l��A�����ĉ�������ꍇ��
	// �A�C�h�����̃^�X�N�����s����B
	// 
	// �A���A���̃��O�L�^�������ԑ������ꍇ�Ƀ^�X�N�����s�ł��Ȃ��Ȃ�
	// ���Ƃ��l�����āA���Ԗʂł̃^�X�N���s�����{����B
	//
	std::deque<int> logCountHist9;

	const int IDLE_TASK_EXECUTE_THRESHOLD = 3;
	int idleCount = 0;

	auto lastExecTime{ chrono::system_clock::now() };

	int prevCount = LogBlock::getCount();

	while (1)
	{
		try
		{
			const chrono::steady_clock::time_point start = chrono::steady_clock::now();

			traceW(L"(%d): wait for signal ...", i);
			const auto reason = ::WaitForSingleObject(mEvent, 1000 * 10);

			switch (reason)
			{
				case WAIT_TIMEOUT:
				{
					const int currCount = LogBlock::getCount();
					const int thisCount = currCount - prevCount;
					prevCount = currCount;

#if 0
					// ������s
					idleCount = IDLE_TASK_EXECUTE_THRESHOLD + 1;

#else
					traceW(L"thisCount=%d", thisCount);

					if (logCountHist9.size() < 9)
					{
						// ���Z�b�g���� 9 ��̓��O�L�^�񐔂����W

						traceW(L"collect log count, %zu", logCountHist9.size());
						idleCount = 0;
					}
					else
					{
						// �ߋ� 9 ��̃��O�L�^�񐔂����l���Z�o

						const int sumHist9 = (int)std::accumulate(logCountHist9.begin(), logCountHist9.end(), 0);
						const int avgHist9 = sumHist9 / (int)logCountHist9.size();

						const int refHist9 = avgHist9 / 4; // 25%

						traceW(L"sumHist9=%d, avgHist9=%d, refHist9=%d", sumHist9, avgHist9, refHist9);

						if (thisCount <= refHist9)
						{
							// ����̋L�^����l�ȉ��Ȃ�A�C�h�����ԂƂ��ăJ�E���g

							idleCount++;
						}
						else
						{
							idleCount = 0;
						}

						logCountHist9.pop_front();
					}

					logCountHist9.push_back(thisCount);
#endif

					break;
				}

				case WAIT_OBJECT_0:
				{
					traceW(L"(%d): wait for signal: catch signal", i);

					// �V�O�i���������͑����Ɏ��s�ł���悤�ɃJ�E���g�𒲐�

					idleCount = IDLE_TASK_EXECUTE_THRESHOLD + 1;

					break;
				}

				default:
				{
					traceW(L"(%d): wait for signal: error code=%ld, continue", i, reason);
					throw std::runtime_error("illegal route");

					break;
				}
			}

			if (lastExecTime < (chrono::system_clock::now() - chrono::minutes(10)))
			{
				// 10 ���ȏ���s����Ă��Ȃ��ꍇ�̋~�ϑ[�u

				idleCount = IDLE_TASK_EXECUTE_THRESHOLD + 1;

				traceW(L"force execute idle-task");
			}

			traceW(L"idleCount: %d", idleCount);

			if (idleCount >= IDLE_TASK_EXECUTE_THRESHOLD)
			{
				// �A�C�h�����Ԃ���萔�A�������ꍇ�A�������͗D��x�������ꍇ�Ƀ^�X�N�����s

				traceW(L"exceeded the threshold.");

				// �L���[�ɓ����Ă���^�X�N������
				const auto tasks{ getTasks() };

				for (const auto& task: tasks)
				{
					if (!task->mPriority == Priority::LOW)
					{
						// �ً}�x�͒Ⴂ�̂ŁA���̃X���b�h��D�悳����

						::SwitchToThread();
					}

					traceW(L"(%d): run idle task ...", i);
					task->_mWorkerId_4debug = i;
					task->run(INIT_CALLER this, LOG_DEPTH());
					traceW(L"(%d): run idle task done", i);

				}

				// �J�E���^�̏�����
				idleCount = 0;

				// �ŏI���s���Ԃ̍X�V
				lastExecTime = chrono::system_clock::now();

				// �L�^�̃��Z�b�g
				logCountHist9.clear();
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


static std::mutex gGuard;

#define THREAD_SAFE() \
    std::lock_guard<std::mutex> lock_(gGuard)


bool IdleWorker::addTask(ITask* task, CanIgnore ignState, Priority priority)
{
	THREAD_SAFE();
	//NEW_LOG_BLOCK();
	APP_ASSERT(task);

#if ENABLE_TASK
	task->mPriority = priority;

	if (priority == Priority::HIGH)
	{
		// �D�悷��ꍇ
		//traceW(L"add highPriority=true");
		mTasks.emplace_front(task);

		// WaitForSingleObject() �ɒʒm
		::SetEvent(mEvent);
	}
	else
	{
		// �ʏ�͂�����
		//traceW(L"add highPriority=false");
		mTasks.emplace_back(task);
	}

	return true;

#else
	// ���[�J�[�����������ȏꍇ�́A�^�X�N�̃��N�G�X�g�𖳎�
	delete task;

	return false;
#endif
}

std::deque<std::shared_ptr<ITask>> IdleWorker::getTasks()
{
	THREAD_SAFE();
	//NEW_LOG_BLOCK();

	return mTasks;
}

// EOF