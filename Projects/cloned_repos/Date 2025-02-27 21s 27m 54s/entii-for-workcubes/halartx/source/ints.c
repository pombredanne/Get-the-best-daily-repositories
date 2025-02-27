// Interrupt handler stuff.

#include "halp.h"
#include "ints.h"

enum {
	MAX_IRQL_NUM = 32
};

PPI_INTERRUPT_REGS HalpPiInterruptRegs = NULL;
IDTUsage        HalpIDTUsage[MAXIMUM_IDTVECTOR];
KINTERRUPT HalpMachineCheckInterrupt;

BOOLEAN HalpInEmulator = FALSE;

// MPNOTE: This should be in the PCR.
ULONG HalpRegisteredInterrupts = 0;

// Table that converts IRQL to interrupt mask register.
// Generated based on HalpInterruptToIrql by HalpInitPriorityMask
ULONG HalpIrqlToMask[MAX_IRQL_NUM];

// Table that converts interrupt bit number to IRQL.
// PROFILE_LEVEL = 27
// CLOCK2_LEVEL = 28
// IPI_LEVEL = 29
// POWER_LEVEL = 30
// HIGH_LEVEL = 31
const ULONG HalpInterruptToIrql[MAX_IRQL_NUM] = {
	28, // ERROR
	23, // RESET
	15, // DVD
	15, // SERIAL
	14, // EXI (used for USB gecko thus kd)
	18, // AUDIO
	18, // DSP
	24, // MEM
	22, // VI
	20, // PE_TOKEN
	20, // PE_FINISH
	16, // CP_FIFO
	25, // DEBUG
	19, // HIGHSPEED_PORT (gone from RVL)
	21, // VEGAS (IOS IPC)
	17, 17, 17, // WAGON
	29, 29, 29, // IPI
	20, // GPU7
	21, // LATTE
};

static BOOLEAN HalpInitPriorityMask(void) {
	for (ULONG Irql = 0; Irql < MAX_IRQL_NUM; Irql++) {
		HalpIrqlToMask[Irql] = 0;
		for (
			ULONG Interrupt = 0;
			Interrupt < sizeof(HalpInterruptToIrql) / sizeof(*HalpInterruptToIrql);
			Interrupt++
		) {
			// Set bits for the interrupts that are still allowed
			if (HalpInterruptToIrql[Interrupt] > Irql) {
				HalpIrqlToMask[Irql] |= BIT(Interrupt);
			}
		}
	}
}

// Initialises and registers an interrupt handler in the HAL
BOOLEAN
HalpEnableInterruptHandler (
    IN PKINTERRUPT Interrupt,
    IN PKSERVICE_ROUTINE ServiceRoutine,
    IN PVOID ServiceContext,
    IN PKSPIN_LOCK SpinLock OPTIONAL,
    IN ULONG Vector,
    IN KIRQL Irql,
    IN KIRQL SynchronizeIrql,
    IN KINTERRUPT_MODE InterruptMode,
    IN BOOLEAN ShareVector,
    IN CCHAR ProcessorNumber,
    IN BOOLEAN FloatingSave,
    IN UCHAR    ReportFlags,
    IN KIRQL BusVector
    )
{
	// Initialise the interrupt.

    KeInitializeInterrupt( Interrupt,
                           ServiceRoutine,
                           ServiceContext,
                           SpinLock,
                           Vector,
                           Irql,
                           SynchronizeIrql,
                           InterruptMode,
                           ShareVector,
                           ProcessorNumber,
                           FloatingSave
                         );


	// Try to connect the interrupt
    if (!KeConnectInterrupt( Interrupt )) {
	return FALSE;
    }

	// Register the interrupt vector
    HalpRegisterVector (ReportFlags, BusVector, Vector, Irql);


    return TRUE;


}

// Registers an interrupt vector.
VOID
HalpRegisterVector (
    IN UCHAR    ReportFlags,
    IN ULONG    BusInterruptVector,
    IN ULONG    SystemInterruptVector,
    IN KIRQL    SystemIrql
    )
{

    //
    // Remember which vector the hal is connecting so it can be reported
    // later on
    //

    HalpIDTUsage[SystemInterruptVector].Flags = ReportFlags;
    HalpIDTUsage[SystemInterruptVector].Irql  = SystemIrql;
    HalpIDTUsage[SystemInterruptVector].BusReleativeVector = (UCHAR) BusInterruptVector;
}

// Disables an interrupt.
void HalDisableSystemInterrupt(ULONG Vector, KIRQL Irql) {
	// Check that we need to do anything.
	if (Vector < DEVICE_VECTORS) return;
	if (Vector >= DEVICE_VECTORS + 32) return;

	// Raise IRQL to the highest level.
	KIRQL OldIrql;
	KeRaiseIrql(HIGH_LEVEL, &OldIrql);
	// MP note: acquire spinlock here
	
	// Get the actual Flipper/Vegas/Cafe interrupt number
	Vector -= DEVICE_VECTORS;
	
	{
		// Turn the interrupt off in our array
		ULONG BitMask = ~(BIT(Vector));
		HalpRegisteredInterrupts &= BitMask;
		// ...and mask it in flipper
		MmioWriteBase32(MMIO_OFFSET(HalpPiInterruptRegs, Mask),
			MmioReadBase32(MMIO_OFFSET(HalpPiInterruptRegs, Mask)) & BitMask
		);
	}
	
	// MP note: release spinlock here
	
	// Lower IRQL
	KeLowerIrql(OldIrql);
}

// Enables an interrupt.
BOOLEAN HalEnableSystemInterrupt(ULONG Vector, KIRQL Irql, KINTERRUPT_MODE InterruptMode) {
	// Check that we need to do anything.
	if (Vector < DEVICE_VECTORS) return FALSE;
	if (Vector >= DEVICE_VECTORS + 32) return FALSE;
	
	// Raise IRQL to the highest level.
	KIRQL OldIrql;
	KeRaiseIrql(HIGH_LEVEL, &OldIrql);
	// MP note: acquire spinlock here
	
	// Get the actual Flipper/Vegas/Cafe interrupt number
	Vector -= DEVICE_VECTORS;
	
	{
		// Turn the interrupt on in our array
		ULONG BitMask = BIT(Vector);
		HalpRegisteredInterrupts |= BitMask;
		// ...and unmask it in flipper
		MmioWriteBase32(MMIO_OFFSET(HalpPiInterruptRegs, Mask),
			MmioReadBase32(MMIO_OFFSET(HalpPiInterruptRegs, Mask)) | BitMask
		);
	}
	
	// MP note: release spinlock here
	
	// Lower IRQL
	KeLowerIrql(OldIrql);
	
	return TRUE;
}

// External interrupt handler;
// called eventually from vector 0x500.
// Calls the handler for the interrupt;
// and write Flipper or Vegas registers to handle it.

#define __mfdec() \
	({ ULONG result; \
	__asm__ volatile ("mfdec %0" : "=r" (result)); \
	/*return*/ result; })

BOOLEAN HalpHandleExternalInterrupt(
	IN PKINTERRUPT Interrupt,
	IN PVOID ServiceContext,
	IN PVOID TrapFrame
) {
	// Read the interrupt cause and mask.
	ULONG Cause = MmioReadBase32(MMIO_OFFSET(HalpPiInterruptRegs, Cause));
	ULONG Mask = MmioReadBase32(MMIO_OFFSET(HalpPiInterruptRegs, Mask));
	
	// Mask off the reset switch value.
	Cause &= ~BIT(16);
	
	// Check for spurious interrupts (first check)
	if (Cause == 0) {
		return FALSE;
	}
	
	ULONG OldCause = Cause;
	
	// Ensure we don't try to service some interrupt that is masked off.
	Cause &= Mask;
	
	// Check for spurious interrupts (second check)
	if (Cause == 0) {
		return FALSE;
	}
	
	// Other PPC HAL may light the hdd-light GPIO here.
	// We do this (for the optical drive light GPIO) inside the actual drivers.
	
	// Find the highest priority interrupt to service.
	ULONG Irql;
	for (Irql = HIGH_LEVEL; Irql > DISPATCH_LEVEL; Irql--) {
		if ((HalpIrqlToMask[Irql] & Cause) == 0) continue;
		break;
	}
	
	Cause &= HalpIrqlToMask[Irql];
	
	// Of the bits remaining, get the highest bit.
	USHORT InterruptNumber = 31 - __builtin_clz(Cause);

	// Set the new IRQL.
	UCHAR OldIrql = PCR->CurrentIrql;
	UCHAR NewIrql = (UCHAR) HalpInterruptToIrql[InterruptNumber];
	PCR->CurrentIrql = NewIrql;
	
	// Mask off all interrupts of lesser priority.
	ULONG CurrentMask = (1 << InterruptNumber);
	// Mask it off in HalpRegisteredInterrupts, so IRQL modifying won't set it back
	// This will avoid recursion when taking a page fault inside an interrupt handler.
	// This will ALSO avoid recursion when turning interrupts back on,
	// before the handler can actually ack the interrupt in the device if needed.
	BOOLEAN IntRegistered = (HalpRegisteredInterrupts & CurrentMask) != 0;
	if (IntRegistered) HalpRegisteredInterrupts &= ~CurrentMask;
	// MP NOTE: there should be multiple sets of HalpRegisteredInterrupts for each cpu!
	MmioWriteBase32(MMIO_OFFSET(HalpPiInterruptRegs, Mask), (HalpIrqlToMask[Irql] & HalpRegisteredInterrupts));
	
	// Acknowledge the handled interrupt, if it's possible to do so here
	// Only interrupt 0-1,12,13 can be acked here,
	// but Dolphin emulates the register incorrectly (for now);
	// and allows all interrupts to be acked here.
	MmioWriteBase32(MMIO_OFFSET(HalpPiInterruptRegs, Cause), CurrentMask);
	
	// If the new IRQL level is lower than CLOCK2,
	// allow decrementer interrupts by reenabling interrupts.
	// This allows kd to break on hang.
	if (Irql < CLOCK2_LEVEL) _enable();
	
	// Dispatch to the higher level ISR.
	PSECONDARY_DISPATCH InterruptHandler = (PSECONDARY_DISPATCH)
		PCR->InterruptRoutine[DEVICE_VECTORS + InterruptNumber];
	
	BOOLEAN ret = FALSE;
	
	// Ensure this interrupt handler is actually valid.
	// Do this by comparing with the unexpected handler.
	if ((ULONG)InterruptHandler != (ULONG)PCR->InterruptRoutine[255]) {
		PKINTERRUPT SecondaryInterrupt =
			CONTAINING_RECORD(InterruptHandler, KINTERRUPT, DispatchCode[0]);
		// Ensure that this interrupt handler is actually valid. Structure size changed between 1314 and 1381.
		if (SecondaryInterrupt->Size == sizeof(*SecondaryInterrupt)) {
			ret = InterruptHandler(SecondaryInterrupt, SecondaryInterrupt->ServiceContext, TrapFrame);
		} else {
			PKINTERRUPT_OLD SecondaryInterruptOld =
				CONTAINING_RECORD(InterruptHandler, KINTERRUPT_OLD, DispatchCode[0]);
			if (SecondaryInterruptOld->Size != sizeof(*SecondaryInterruptOld)) {
				// nothing can be done here~
				HalDisplayString("HAL: KINTERRUPT size for this build is unknown\n");
				KeBugCheck(MISMATCHED_HAL);
			}
			ret = InterruptHandler(SecondaryInterruptOld, SecondaryInterruptOld->ServiceContext, TrapFrame);
		}
	}
	
	// Disable interrupts for IRQL lowering
	_disable();

	// Reenable the masked off interrupt
	if (IntRegistered) HalpRegisteredInterrupts |= CurrentMask;
	
	// Lower the IRQL
	PCR->CurrentIrql = OldIrql;
	MmioWriteBase32(MMIO_OFFSET(HalpPiInterruptRegs, Mask), Mask);
	return ret;
}

// Handle IPI interrupt
// MPNOTE: finish
/*
BOOLEAN HalpHandleIpiInterrupt(
	IN PKINTERRUPT Interrupt,
	IN PVOID ServiceContext,
	IN PVOID TrapFrame
) {
	if (HalAcknowledgeIpi()) {
		KeIpiInterrupt(TrapFrame);
		return TRUE;
	}
	return FALSE;
}
*/

// Map the PI interrupt registers (stage 0)
static BOOLEAN HalpMapInterruptRegs0(void) {
	if (HalpPiInterruptRegs != NULL) return TRUE;
	HalpPiInterruptRegs = KePhase0MapIo(PI_INTERRUPT_REGS_BASE, sizeof(PI_INTERRUPT_REGS));
	return HalpPiInterruptRegs != NULL;
}

// Map the PI interrupt registers
BOOLEAN HalpMapInterruptRegs(void) {
	BOOLEAN HasBatMapping = (HalpPiInterruptRegs != NULL);
	
	// Map the registers via the NT memory manager.
	PHYSICAL_ADDRESS physAddr;
	physAddr.HighPart = 0;
	physAddr.LowPart = PI_INTERRUPT_REGS_BASE;
	HalpPiInterruptRegs = (PPI_INTERRUPT_REGS)
		MmMapIoSpace(physAddr, sizeof(PI_INTERRUPT_REGS), FALSE);
	
	// Ensure any BAT mapping is gone.
	// Do this after mapping by page tables:
	// if unmap happens first, an interrupt in MmMapIoSpace is death.
	if (HasBatMapping) {
		KePhase0DeleteIoMap(PI_INTERRUPT_REGS_BASE, sizeof(PI_INTERRUPT_REGS));
	}
	
	if (HalpPiInterruptRegs == NULL) return FALSE;
	return TRUE;
}

BOOLEAN HalpEnableDeviceInterruptHandler(
    IN PKINTERRUPT Interrupt,
    IN PKSERVICE_ROUTINE ServiceRoutine,
    IN PVOID ServiceContext,
    IN PKSPIN_LOCK SpinLock OPTIONAL,
    IN INTERRUPT_VECTOR Vector,
    IN KINTERRUPT_MODE InterruptMode,
    IN BOOLEAN ShareVector,
    IN CCHAR ProcessorNumber,
    IN BOOLEAN FloatingSave,
    IN UCHAR    ReportFlags
) {
	ULONG NtVector = DEVICE_VECTORS + (ULONG)Vector;
	KIRQL Irql = HalpInterruptToIrql[Vector];
	return HalpEnableInterruptHandler(
		Interrupt, ServiceRoutine, ServiceContext, SpinLock,
		NtVector, Irql, Irql,
		InterruptMode, ShareVector, ProcessorNumber,
		FloatingSave, ReportFlags, (KIRQL)NtVector
	);
}

void HalpDisableDeviceInterruptHandler(INTERRUPT_VECTOR Vector) {
	ULONG NtVector = DEVICE_VECTORS + (ULONG)Vector;
	KIRQL Irql = HalpInterruptToIrql[Vector];
	HalDisableSystemInterrupt(NtVector, Irql);
}

KIRQL HalpRaiseDeviceIrql(INTERRUPT_VECTOR Vector) {
	KIRQL OldIrql;
	KIRQL Irql = HalpInterruptToIrql[Vector];
	KeRaiseIrql(Irql, &OldIrql);
	return OldIrql;
}

BOOLEAN HalpCreateSioStructures(void) {
	// Ensure interrupts are disabled.
	_disable();
	
	// Ensure the IRQL to interrupt mask table is initialised.
	HalpInitPriorityMask();
	
	// Initialise the Machine Check interrupt handler
	if (HalpEnableInterruptHandler(&HalpMachineCheckInterrupt,
									HalpHandleMachineCheck,
									NULL,
									NULL,
									MACHINE_CHECK_VECTOR,
									MACHINE_CHECK_LEVEL,
									MACHINE_CHECK_LEVEL,
									Latched,
									FALSE,
									0,
									FALSE,
									InternalUsage,
									MACHINE_CHECK_VECTOR
								) == FALSE) {
		KeBugCheck(HAL_INITIALIZATION_FAILED);
	}
	
	// Initialise the external interrupt handler
	PCR->InterruptRoutine[EXTERNAL_INTERRUPT_VECTOR] = (PKINTERRUPT_ROUTINE)HalpHandleExternalInterrupt;
	HalpRegisterVector(InternalUsage, EXTERNAL_INTERRUPT_VECTOR, EXTERNAL_INTERRUPT_VECTOR, HIGH_LEVEL);
	
	// Initialise the decrementer handler
	PCR->InterruptRoutine[DECREMENT_VECTOR] = (PKINTERRUPT_ROUTINE)HalpHandleDecrementerInterrupt;
	
	// Initialise the decrementer itself.
	HalpUpdateDecrementer(1000);
	
	return TRUE;
}

BOOLEAN HalpInitialiseInterrupts(void) {
	// Ensure interrupts are disabled.
	_disable();
	
	// Map the PI interrupt registers for stage 0 init.
	if (!HalpMapInterruptRegs0()) return FALSE;
	
	// Ensure all hardware interrupts are disabled.
	MmioWriteBase32(MMIO_OFFSET(HalpPiInterruptRegs, Mask), 0);
	HalpRegisteredInterrupts = 0;
	
	// Get the emulator status passed to us from arc firmware
	HalpInEmulator = RUNTIME_BLOCK[RUNTIME_IN_EMULATOR] != FALSE;
	
	// Reserve the external interrupt vector for the HAL
	PCR->ReservedVectors |= (1 << EXTERNAL_INTERRUPT_VECTOR);
	
	return TRUE;
}