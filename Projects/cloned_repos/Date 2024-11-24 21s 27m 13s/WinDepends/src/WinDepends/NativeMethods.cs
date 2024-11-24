﻿/*******************************************************************************
*
*  (C) COPYRIGHT AUTHORS, 2024
*
*  TITLE:       NATIVEMETHODS.CS
*
*  VERSION:     1.00
*  
*  DATE:        24 Sep 2024
*
*  Win32 API P/Invoke.
*
* THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF
* ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED
* TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
* PARTICULAR PURPOSE.
*
*******************************************************************************/
using System.Runtime.InteropServices;
using System.Text;

namespace WinDepends;

static partial class NativeMethods
{
    #region "P/Invoke stuff"

    internal static ushort LOWORD(this int value) => (ushort)(value & 0xffff);
    internal static ushort HIWORD(this int value) => (ushort)(value >> 16 & 0xffff);
    internal static ushort LOWORD(this uint value) => (ushort)(value & 0xffff);
    internal static ushort HIWORD(this uint value) => (ushort)(value >> 16 & 0xffff);
    internal static long LARGE_INTEGER(uint LowPart, int HighPart) => LowPart | (long)HighPart << 32;

    //
    // Summary:
    //     Represents the Common Object File Format (COFF) file extended characteristics.
    [Flags]
    public enum CharacteristicsEx : ushort
    {
        //
        // Summary:
        //     Indicates that the image is Control-flow Enforcement Technology (CET) Shadow Stack compatible.
        //
        SetCompat = 1,

        //
        // Summary:
        //     All branch targets in all image code sections are annotated with forward-edge control flow integrity
        //     guard instructions such as x86 CET-Indirect Branch Tracking (IBT) or ARM Branch Target Identification (BTI) instructions.
        //
        ForwardCfiCompat = 64
    }

    internal const uint STGM_READ = 0;
    internal const int MAX_PATH = 260;
    internal const int BCM_FIRST = 0x1600;
    internal const int BCM_SETSHIELD = (BCM_FIRST + 0x000C);

    [StructLayout(LayoutKind.Sequential)]
    public struct SHELLEXECUTEINFO
    {
        public int cbSize;
        public ShellExecuteMaskFlags fMask;
        public IntPtr hwnd;
        [MarshalAs(UnmanagedType.LPTStr)]
        public string lpVerb;
        [MarshalAs(UnmanagedType.LPTStr)]
        public string lpFile;
        [MarshalAs(UnmanagedType.LPTStr)]
        public string lpParameters;
        [MarshalAs(UnmanagedType.LPTStr)]
        public string lpDirectory;
        public ShowCommands nShow;
        public IntPtr hInstApp;
        public IntPtr lpIDList;
        [MarshalAs(UnmanagedType.LPTStr)]
        public string lpClass;
        public IntPtr hkeyClass;
        public uint dwHotKey;
        public IntPtr hIcon;
        public IntPtr hProcess;
    }

    public enum ShowCommands : int
    {
        SW_HIDE = 0,
        SW_SHOWNORMAL = 1,
        SW_SHOWMINIMIZED = 2,
        SW_SHOWMAXIMIZED = 3,
        SW_SHOWNOACTIVATE = 4,
        SW_SHOW = 5,
        SW_MINIMIZE = 6,
        SW_SHOWMINNOACTIVE = 7,
        SW_SHOWNA = 8,
        SW_RESTORE = 9,
        SW_SHOWDEFAULT = 10,
        SW_FORCEMINIMIZE = 11,
    }

    [Flags]
    public enum ShellExecuteMaskFlags : uint
    {
        SEE_MASK_DEFAULT = 0x00000000,
        SEE_MASK_CLASSNAME = 0x00000001,
        SEE_MASK_CLASSKEY = 0x00000003,
        SEE_MASK_IDLIST = 0x00000004,
        SEE_MASK_INVOKEIDLIST = 0x0000000c,   // SEE_MASK_INVOKEIDLIST(0xC) implies SEE_MASK_IDLIST(0x04) 
        SEE_MASK_HOTKEY = 0x00000020,
        SEE_MASK_NOCLOSEPROCESS = 0x00000040,
        SEE_MASK_CONNECTNETDRV = 0x00000080,
        SEE_MASK_NOASYNC = 0x00000100,
        SEE_MASK_FLAG_DDEWAIT = SEE_MASK_NOASYNC,
        SEE_MASK_DOENVSUBST = 0x00000200,
        SEE_MASK_FLAG_NO_UI = 0x00000400,
        SEE_MASK_UNICODE = 0x00004000,
        SEE_MASK_NO_CONSOLE = 0x00008000,
        SEE_MASK_ASYNCOK = 0x00100000,
        SEE_MASK_HMONITOR = 0x00200000,
        SEE_MASK_NOZONECHECKS = 0x00800000,
        SEE_MASK_NOQUERYCLASSSTORE = 0x01000000,
        SEE_MASK_WAITFORINPUTIDLE = 0x02000000,
        SEE_MASK_FLAG_LOG_USAGE = 0x04000000,
    }

    public const ushort IMAGE_SUBSYSTEM_NATIVE = 0x0001;
    public const ushort IMAGE_FILE_EXECUTABLE_IMAGE = 0x2;
    public const ushort IMAGE_FILE_DLL = 0x2000;

    public const ushort PROCESSOR_ARCHITECTURE_INTEL = 0;
    public const ushort PROCESSOR_ARCHITECTURE_ARM = 5;
    public const ushort PROCESSOR_ARCHITECTURE_IA64 = 6;
    public const ushort PROCESSOR_ARCHITECTURE_AMD64 = 9;
    public const ushort PROCESSOR_ARCHITECTURE_ARM64 = 12;

    [StructLayout(LayoutKind.Sequential)]
    public struct SYSTEM_INFO
    {
        public ushort wProcessorArchitecture;
        public ushort wReserved;
        public uint dwPageSize;
        public IntPtr lpMinimumApplicationAddress;
        public IntPtr lpMaximumApplicationAddress;
        public IntPtr dwActiveProcessorMask;
        public uint dwNumberOfProcessors;
        public uint dwProcessorType;
        public uint dwAllocationGranularity;
        public ushort wProcessorLevel;
        public ushort wProcessorRevision;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public sealed class MEMORYSTATUSEX
    {
        public uint dwLength;
        public uint dwMemoryLoad;
        public ulong ullTotalPhys;
        public ulong ullAvailPhys;
        public ulong ullTotalPageFile;
        public ulong ullAvailPageFile;
        public ulong ullTotalVirtual;
        public ulong ullAvailVirtual;
        public ulong ullAvailExtendedVirtual;
        public MEMORYSTATUSEX()
        {
            dwLength = (uint)Marshal.SizeOf(typeof(NativeMethods.MEMORYSTATUSEX));
        }

    }

    public sealed class HResult
    {
        public const int S_OK = 0;
        public const int E_ACCESSDENIED = unchecked((int)0x80070005);
        public const int E_INVALIDARG = unchecked((int)0x80070057);
        public const int E_OUTOFMEMORY = unchecked((int)0x8007000E);
        public const int STG_E_ACCESSDENIED = unchecked((int)0x80030005);
    }

    [DllImport("kernel32.dll")]
    internal static extern void GetSystemInfo(ref SYSTEM_INFO lpSystemInfo);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool GlobalMemoryStatusEx([In, Out] MEMORYSTATUSEX lpBuffer);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool ChangeWindowMessageFilterEx(IntPtr hWnd, uint msg, ChangeWindowMessageFilterExAction action, ref CHANGEFILTERSTRUCT changeInfo);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    internal static extern UInt32 SendMessage(IntPtr hWnd, UInt32 msg, UInt32 wParam, UInt32 lParam);

    [DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool ShellExecuteEx(ref SHELLEXECUTEINFO lpExecInfo);

    [DllImport("shell32.dll", SetLastError = true)]
    internal static extern void DragAcceptFiles(IntPtr hwnd, bool fAccept);

    [DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    internal static extern uint DragQueryFile(IntPtr hDrop, uint iFile, [Out] StringBuilder lpszFile, uint cch);

    [DllImport("shell32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool DragQueryPoint(IntPtr hDrop, ref POINT lppt);

    [DllImport("shell32.dll", SetLastError = true)]
    internal static extern void DragFinish(IntPtr hDrop);

    [DllImport("dbghelp.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    internal static extern uint UnDecorateSymbolName(
        [MarshalAs(UnmanagedType.LPWStr)] string name,
        [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder outputString,
        int maxStringLength,
        UNDNAME flags
    );

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern uint SearchPath([MarshalAs(UnmanagedType.LPWStr)] string lpPath,
        [MarshalAs(UnmanagedType.LPWStr)] string lpFileName,
        [MarshalAs(UnmanagedType.LPWStr)] string lpExtension,
        UInt32 nBufferLength,
        [MarshalAs(UnmanagedType.LPWStr)] StringBuilder lpBuffer,
        out IntPtr lpFilePart);

    [Flags]
    public enum UNDNAME : uint
    {
        /// <summary>Undecorate 32-bit decorated names.</summary>
        Decode32Bit = 0x0800,

        /// <summary>Enable full undecoration.</summary>
        Complete = 0x0000,

        /// <summary>Undecorate only the name for primary declaration. Returns [scope::]name. Does expand template parameters.</summary>
        NameOnly = 0x1000,

        /// <summary>Disable expansion of access specifiers for members.</summary>
        NoAccessSpecifiers = 0x0080,

        /// <summary>Disable expansion of the declaration language specifier.</summary>
        NoAllocateLanguage = 0x0010,

        /// <summary>Disable expansion of the declaration model.</summary>
        NoAllocationModel = 0x0008,

        /// <summary>Do not undecorate function arguments.</summary>
        NoArguments = 0x2000,

        /// <summary>Disable expansion of CodeView modifiers on the this type for primary declaration.</summary>
        NoCVThisType = 0x0040,

        /// <summary>Disable expansion of return types for primary declarations.</summary>
        NoFunctionReturns = 0x0004,

        /// <summary>Remove leading underscores from Microsoft keywords.</summary>
        NoLeadingUndersCores = 0x0001,

        /// <summary>Disable expansion of the static or virtual attribute of members.</summary>
        NoMemberType = 0x0200,

        /// <summary>Disable expansion of Microsoft keywords.</summary>
        NoMsKeyWords = 0x0002,

        /// <summary>Disable expansion of Microsoft keywords on the this type for primary declaration.</summary>
        NoMsThisType = 0x0020,

        /// <summary>Disable expansion of the Microsoft model for user-defined type returns.</summary>
        NoReturnUDTModel = 0x0400,

        /// <summary>Do not undecorate special names, such as vtable, vcall, vector, metatype, and so on.</summary>
        NoSpecialSyms = 0x4000,

        /// <summary>Disable all modifiers on the this type.</summary>
        NoThisType = 0x0060,

        /// <summary>Disable expansion of throw-signatures for functions and pointers to functions.</summary>
        NoThrowSignatures = 0x0100,
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct POINT(int newX, int newY)
    {
        public int X = newX;
        public int Y = newY;

        public static implicit operator System.Drawing.Point(POINT p)
        {
            return new System.Drawing.Point(p.X, p.Y);
        }
        public static implicit operator POINT(System.Drawing.Point p)
        {
            return new POINT(p.X, p.Y);
        }
    }

    internal enum MessageFilterInfo : uint
    {
        None,
        AlreadyAllowed,
        AlreadyDisAllowed,
        AllowedHigher
    }
    internal enum ChangeWindowMessageFilterExAction : uint
    {
        Reset,
        Allow,
        Disallow
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct CHANGEFILTERSTRUCT
    {
        public uint cbSize;
        public MessageFilterInfo ExtStatus;
    }

    #endregion

    /// <summary>
    /// Adds an UAC shield icon to the Button control.
    /// </summary>
    /// <param name="b"></param>
    /// <returns></returns>
    static internal uint AddShieldToButton(Button b)
    {
        b.FlatStyle = FlatStyle.System;
        return SendMessage(b.Handle, BCM_SETSHIELD, 0, 0xFFFFFFFF);
    }

    /// <summary>
    /// Runs explorer "properties" dialog.
    /// </summary>
    /// <param name="fileName"></param>
    /// <returns></returns>
    static internal bool ShowFileProperties(string fileName)
    {
        try
        {
            SHELLEXECUTEINFO info = new()
            {
                cbSize = Convert.ToInt32(Marshal.SizeOf(typeof(SHELLEXECUTEINFO))),
                lpVerb = "properties",
                lpFile = fileName,
                nShow = ShowCommands.SW_SHOW,
                fMask = ShellExecuteMaskFlags.SEE_MASK_INVOKEIDLIST
            };
            return ShellExecuteEx(ref info);
        }
        catch { return false; }
    }

    /// <summary>
    /// Resolves shortcut (lnk) path.
    /// </summary>
    /// <param name="LnkFileName"></param>
    /// <returns>Resolved path string or null in case of error.</returns>
    static internal string ResolveShortcutTarget(string LnkFileName)
    {
        try
        {
            var link = new ShellLink();
            int result = ((IPersistFile)link).Load(LnkFileName, STGM_READ);
            if (HResult.S_OK == result)
            {
                StringBuilder pszFile = new(MAX_PATH);
                WIN32_FIND_DATAW _ = new();
                result = ((IShellLinkW)link).GetPath(pszFile, pszFile.Capacity, out _, 0);
                if (HResult.S_OK == result)
                {
                    return pszFile.ToString();
                }
            }

        }
        catch { }

        return null;
    }

    /// <summary>
    /// Call dbghelp!UnDecorateSymbolName to undecorate name.
    /// </summary>
    /// <param name="functionName"></param>
    /// <returns></returns>
    static internal string UndecorateFunctionName(string functionName)
    {
        var sb = new StringBuilder(128);

        if (UnDecorateSymbolName(functionName, sb, sb.Capacity, UNDNAME.Complete) > 0)
        {
            return sb.ToString();
        }

        return string.Empty;
    }
}

/// <summary>
/// Elevated Drag&Drop message filter class.
/// </summary>
public class ElevatedDragDropManager : IMessageFilter
{
    private static readonly ElevatedDragDropManager Instance = new();
    public event EventHandler<ElevatedDragDropEventArgs> ElevatedDragDrop;
    private const uint WM_DROPFILES = 0x233;
    private const uint WM_COPYDATA = 0x4a;
    private const uint WM_COPYGLOBALDATA = 0x49;

    protected ElevatedDragDropManager()
    {
        Application.AddMessageFilter(this);
    }

    public static ElevatedDragDropManager GetInstance()
    {
        return Instance;
    }

    public static void EnableDragDrop(IntPtr hWnd)
    {
        NativeMethods.CHANGEFILTERSTRUCT changeStruct = new()
        {
            cbSize = Convert.ToUInt32(Marshal.SizeOf(typeof(NativeMethods.CHANGEFILTERSTRUCT)))
        };
        NativeMethods.ChangeWindowMessageFilterEx(hWnd, WM_DROPFILES, NativeMethods.ChangeWindowMessageFilterExAction.Allow, ref changeStruct);
        NativeMethods.ChangeWindowMessageFilterEx(hWnd, WM_COPYDATA, NativeMethods.ChangeWindowMessageFilterExAction.Allow, ref changeStruct);
        NativeMethods.ChangeWindowMessageFilterEx(hWnd, WM_COPYGLOBALDATA, NativeMethods.ChangeWindowMessageFilterExAction.Allow, ref changeStruct);
        NativeMethods.DragAcceptFiles(hWnd, true);
    }

    public bool PreFilterMessage(ref Message m)
    {
        if (m.Msg == WM_DROPFILES)
        {
            HandleDragDropMessage(m);
            return true;
        }
        return false;
    }

    private void HandleDragDropMessage(Message m)
    {
        var sb = new StringBuilder(1024);
        uint numFiles = NativeMethods.DragQueryFile(m.WParam, 0xffffffffu, sb, 0);
        var list = new List<string>();

        for (uint i = 0; i < numFiles; i++)
        {
            if (NativeMethods.DragQueryFile(m.WParam, i, sb, Convert.ToUInt32(sb.Capacity) * 2) > 0)
            {
                list.Add(sb.ToString());
            }
        }

        var point = new NativeMethods.POINT();
        NativeMethods.DragQueryPoint(m.WParam, ref point);
        NativeMethods.DragFinish(m.WParam);

        var args = new ElevatedDragDropEventArgs
        {
            HWnd = m.HWnd,
            Files = list,
            X = point.X,
            Y = point.Y
        };

        ElevatedDragDrop?.Invoke(this, args);
    }
}
public class ElevatedDragDropEventArgs : EventArgs
{
    public IntPtr HWnd
    {
        get { return m_HWnd; }
        set { m_HWnd = value; }
    }
    private IntPtr m_HWnd;
    public List<string> Files
    {
        get { return m_Files; }
        set { m_Files = value; }
    }
    private List<string> m_Files;
    public int X
    {
        get { return m_X; }
        set { m_X = value; }
    }
    private int m_X;
    public int Y
    {
        get { return m_Y; }
        set { m_Y = value; }
    }
    private int m_Y;
    public ElevatedDragDropEventArgs()
    {
        Files = [];
    }
}
