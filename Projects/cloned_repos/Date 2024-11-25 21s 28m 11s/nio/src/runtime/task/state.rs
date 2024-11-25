use std::{
    fmt,
    sync::atomic::{
        AtomicUsize,
        Ordering::{AcqRel, Acquire},
    },
};

/// The task is waiting in the queue, Ready to make progress when polled again.
pub const NOTIFIED: usize = 1;

// The task is currently being run.
pub const RUNNING: usize = 2;

/// The task is sleeping, waiting to be woken up for further execution.
pub const SLEEP: usize = 3;

/// The task was polled but did not complete. It was woken while in the `RUNNING` state,
/// meaning it should be polled again to make further progress.
pub const YIELD: usize = 4;

/// The task has been cancelled and will not be polled again.
pub const ABORT: usize = 5;

/// The task has been polled and has finished execution.
pub const COMPLETE: usize = 0b111;

/// The join handle is still around.
pub const JOIN_INTEREST: usize = 0b1_000;

/// A join handle waker has been set.
pub const JOIN_WAKER: usize = 0b10_000;

pub type UpdateResult = Result<Snapshot, Snapshot>;

pub struct State(AtomicUsize);

impl State {
    pub fn new() -> Self {
        Self(AtomicUsize::new(NOTIFIED | JOIN_INTEREST))
    }

    pub fn load(&self) -> Snapshot {
        Snapshot(self.0.load(Acquire))
    }

    pub fn fetch_update<F>(&self, mut f: F) -> Result<Snapshot, Snapshot>
    where
        F: FnMut(Snapshot) -> Option<Snapshot>,
    {
        let mut prev = self.load();
        while let Some(next) = f(prev) {
            match self
                .0
                .compare_exchange_weak(prev.0, next.0, AcqRel, Acquire)
            {
                Ok(v) => return Ok(Snapshot(v)),
                Err(next_prev) => prev = Snapshot(next_prev),
            }
        }
        Err(prev)
    }

    pub fn set_complete(&self) -> Snapshot {
        Snapshot(self.0.fetch_or(COMPLETE, AcqRel))
    }

    pub fn unset_join_interested(&self) -> UpdateResult {
        self.fetch_update(|snapshot| {
            debug_assert!(snapshot.has(JOIN_INTEREST));
            if snapshot.is(COMPLETE) {
                return None;
            }
            Some(snapshot.remove(JOIN_INTEREST))
        })
    }

    pub fn set_join_waker(&self) -> UpdateResult {
        self.fetch_update(|snapshot| {
            debug_assert!(snapshot.has(JOIN_INTEREST));
            debug_assert!(!snapshot.has(JOIN_WAKER));

            if snapshot.is(COMPLETE) {
                return None;
            }
            Some(snapshot.with(JOIN_WAKER))
        })
    }

    pub fn unset_waker(&self) -> UpdateResult {
        self.fetch_update(|snapshot| {
            debug_assert!(snapshot.has(JOIN_INTEREST));
            debug_assert!(snapshot.has(JOIN_WAKER));

            if snapshot.is(COMPLETE) {
                return None;
            }
            Some(snapshot.remove(JOIN_WAKER))
        })
    }
}

/// Current state value.
#[derive(Copy, Clone)]
pub struct Snapshot(usize);

impl Snapshot {
    pub fn get(&self) -> usize {
        self.0 & 0b_111
    }

    pub fn set(&self, state: usize) -> Snapshot {
        Self((self.0 & !0b_111) | state)
    }

    pub fn is(&self, state: usize) -> bool {
        self.0 & 0b_111 == state
    }

    pub fn has(&self, flag: usize) -> bool {
        self.0 & flag == flag
    }

    fn with(&self, flag: usize) -> Snapshot {
        Self(self.0 | flag)
    }

    fn remove(&self, flag: usize) -> Snapshot {
        Self(self.0 & !flag)
    }
}

impl fmt::Debug for Snapshot {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Snapshot")
            .field(
                "state",
                &match self.get() {
                    NOTIFIED => "NOTIFIED",
                    RUNNING => "RUNNING",
                    SLEEP => "SLEEP",
                    YIELD => "YIELD",
                    ABORT => "ABORT",
                    COMPLETE => "COMPLETE",
                    _ => "UNKNOWN",
                },
            )
            .field("JOIN_INTEREST", &self.has(JOIN_INTEREST))
            .field("JOIN_WAKER", &self.has(JOIN_WAKER))
            .finish()
    }
}
