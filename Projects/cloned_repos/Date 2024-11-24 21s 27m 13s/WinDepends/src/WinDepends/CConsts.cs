﻿/*******************************************************************************
*
*  (C) COPYRIGHT AUTHORS, 2024
*
*  TITLE:       CCONSTS.CS
*
*  VERSION:     1.00
*
*  DATE:        09 Nov 2024
*
* THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF
* ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED
* TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
* PARTICULAR PURPOSE.
*
*******************************************************************************/
namespace WinDepends;

public static class CConsts
{
    public const string ProgramName = "Windows Dependencies";
    public const string ShortProgramName = "WinDepends";
    public const string CopyrightString = "© 2024 WinDepends Project Authors";

    public const string NotAvailableMsg = "N/A";
    public const string NotBoundMsg = "Not bound";
    public const string NoneMsg = "None";
    public const string NoResponseMsg = "No response";

    public const string DateTimeFormat24Hours = "dd/MM/yyyy HH:mm:ss";

    public const uint DefaultAppStartAddress = 0x1000000;

    public const uint VersionMajor = 1;
    public const uint VersionMinor = 0;
    public const uint VersionRevision = 0;
    public const uint VersionBuild = 2411;

    public const int HistoryDepthMax = 32;
    public const int HistoryDepthDefault = 10;

    public const int ModuleNodeDepthLimit = 255;
    public const int ModuleNodeDepthDefault = 2;

    public const int TagUseESC = 100;

    public const int TagAutoExpand = 120;
    public const int TagFullPaths = 121;
    public const int TagViewUndecorated = 122;
    public const int TagResolveAPIsets = 123;
    public const int TagUpperCaseModuleNames = 124;
    public const int TagClearLogOnFileOpen = 125;
    public const int TagViewExternalViewer = 200;
    public const int TagViewProperties = 201;
    public const int TagSystemInformation = 300;
    public const int TagConfiguration = 301;
    public const int TagCompressSessionFiles = 400;
    public const int TagUseApiSetSchema = 500;
    public const int TagHighlightApiSet = 501;
    public const int TagUseRelocForImages = 600;

    public const int ModuleIconsAllHeight = 15;
    public const int ModuleIconsAllWidth = 26;
    public const int FunctionIconsHeigth = 14;
    public const int FunctionIconsWidth = 30;
    public const int ModuleIconsHeight = 15;
    public const int ModuleIconsWidth = 26;

    public const int ToolBarIconsHeigth = 16;
    public const int ToolBarIconsWidth = 15;

    public const int SearchOrderIconsWidth = 18;
    public const int SearchOrderIconsHeigth = 17;

    /// <summary>
    /// Count of LVImports, LVExports columns.
    /// </summary>
    public const int FunctionsColumnsCount = 4;
    /// <summary>
    /// Count of LVModules columns.
    /// </summary>
    public const int ModulesColumnsCount = 20;

    /// <summary>
    /// Setting value names.
    /// </summary>
    public const string ExternalFunctionHelpURL = "https://learn.microsoft.com/en-us/search/?terms=%1";

    /// <summary>
    /// Name of working lists.
    /// </summary>
    public const string TVModulesName = "TVModules";
    public const string LVModulesName = "LVModules";
    public const string LVImportsName = "LVImports";
    public const string LVExportsName = "LVExports";

    /// <summary>
    /// Up, down sort marks.
    /// </summary>
    public const string AscendSortMark = "\u25B2";
    public const string DescendSortMark = "\u25BC";

    //
    // Session file extension
    //
    public const string WinDependsSessionFileExt = ".wds";

    //
    // Shortcut file extension
    //
    public const string ShortcutFileExt = ".lnk";

    //
    // Common open dialog filter extensions.
    //
    public const string HandledFileExtensionsMsg = "Handled File Extensions|";
    public const string WinDependsFilter = "|WinDepends session view (*.wds)|*.wds|All files (*.*)|*.*";
    public const string ConfigBrowseFilter = "Executable files (*.exe)|*.exe|All files (*.*)|*.*";

    //
    // System stuff.
    //
    public const string ExplorerApp = "explorer.exe";
    public const string HostSysDir = "system32";
    public const string HostSys16Dir = "system";
    public const string DriversDir = "drivers";

    public const string NtoskrnlExe = "ntoskrnl.exe";
    public const string NtdllDll = "ntdll.dll";
    public const string Kernel32Dll = "kernel32.dll";
    public const string KdComDll = "kdcom.dll";
    public const string BootVidDll = "bootvid.dll";
    public const string HalDll = "hal.dll";

    //
    // WinDepends server app.
    //
    public const string WinDependsCoreApp = "WinDepends.Core";

    public const string CoreServerAddress = "127.0.0.1";
    public const int CoreServerPort = 8209;
    public const int CoreServerChainSizeMax = 32762;

    /// <summary>
    /// Msg: OK
    /// </summary>
    public const string WDEP_STATUS_200 = "WDEP/1.0 200 OK\r\n";
    /// <summary>
    /// Msg: Already resolved
    /// </summary>
    public const string WDEP_STATUS_208 = "WDEP/1.0 208 Already resolved\r\n";
    /// <summary>
    /// Msg: Invalid parameters received
    /// </summary>
    public const string WDEP_STATUS_400 = "WDEP/1.0 400 Invalid parameters received\r\n";
    /// <summary>
    /// Msg: Can not read file headers
    /// </summary>
    public const string WDEP_STATUS_403 = "WDEP/1.0 403 Can not read file headers\r\n";
    /// <summary>
    /// Msg: File not found or can not be accessed
    /// </summary>
    public const string WDEP_STATUS_404 = "WDEP/1.0 404 File not found or can not be accessed\r\n";
    /// <summary>
    /// Msg: Invaild file headers or signatures
    /// </summary>
    public const string WDEP_STATUS_415 = "WDEP/1.0 415 Invalid file headers or signatures\r\n";
    /// <summary>
    /// Msg: Can not allocate resources
    /// </summary>
    public const string WDEP_STATUS_500 = "WDEP/1.0 500 Can not allocate resources\r\n";
    /// <summary>
    /// Msg: Exception in get_datadirs routine
    /// </summary>
    public const string WDEP_STATUS_600 = "WDEP/1.0 600 Exception in get_datadirs routine\r\n";
    /// <summary>
    /// Msg: Exception in get_headers routine
    /// </summary>
    public const string WDEP_STATUS_601 = "WDEP/1.0 601 Exception in get_headers routine\r\n";
    /// <summary>
    /// Msg: Exception in get_imports routine
    /// </summary>
    public const string WDEP_STATUS_602 = "WDEP/1.0 602 Exception in get_imports routine\r\n";
    /// <summary>
    /// Msg: Exception in get_exports routine
    /// </summary>
    public const string WDEP_STATUS_603 = "WDEP/1.0 603 Exception in get_exports routine\r\n";
}

/// <summary>
/// LVImports/LVExports image indexes.
/// </summary>
public enum FunctionsColumns : int
{
    Image = 0,
    Ordinal,
    Hint,
    Name,
    EntryPoint
}

public static class FunctionsColumnsExtension
{
    /// <summary>
    /// Return FunctionsColumns enum value as int.
    /// </summary>
    /// <param name="column"></param>
    /// <returns></returns>
    public static int ToInt(this FunctionsColumns column)
    {
        return (int)column;
    }
}

/// <summary>
/// LVModules column indexes.
/// </summary>
public enum ModulesColumns : int
{
    Image = 0,
    Name,
    FileTimeStamp,
    LinkTimeStamp,
    FileSize,
    Attributes,
    LinkChecksum,
    RealChecksum,
    CPU,
    Subsystem,
    Symbols,
    PrefferedBase,
    ActualBase,
    VirtualSize,
    LoadOrder,
    FileVer,
    ProductVer,
    ImageVer,
    LinkerVer,
    OSVer,
    SubsystemVer
}

public static class ModulesColumnsExtension
{
    /// <summary>
    /// Return ModulesColumns enum value as int.
    /// </summary>
    /// <param name="column"></param>
    /// <returns></returns>
    public static int ToInt(this ModulesColumns column)
    {
        return (int)column;
    }
}

public enum SearchOderIconType
{
    Magnifier = 0,
    Module,
    ModuleBad,
    Directory,
    DirectoryBad
}

public enum ToolBarIconType
{
    OpenFile = 0,
    SaveFile,
    Copy,
    AutoExpand,
    FullPaths,
    ViewUndecorated,
    ViewModulesInExternalViewer,
    Properties,
    SystemInformation,
    Configuration,
    ResolveAPISets
}

public enum ModuleIconType
{
    /// <summary>
    /// Missing module.
    /// </summary>
    MissingModule = 0,

    /// <summary>
    /// Invalid module.
    /// </summary>
    InvalidModule,

    /// <summary>
    /// Normal module with no errors. 
    /// </summary>
    NormalModule,

    /// <summary>
    /// Duplicate module processed somewhere in the tree.
    /// </summary>
    DuplicateModule,

    /// <summary>
    /// Warning for module.
    /// </summary>
    WarningModule,

    /// <summary>
    /// Duplicate module processed with warnings somewhere in the tree.
    /// </summary>
    DuplicateModuleWarning,

    /// <summary>
    /// Normal 64-bit module with no errors.
    /// </summary>
    NormalModule64,

    /// <summary>
    /// Duplicate 64-bit module processed somewhere in the tree.
    /// </summary>
    DuplicateModule64,

    /// <summary>
    /// Warning for module 64-bit.
    /// </summary>
    WarningModule64,

    /// <summary>
    /// Duplicate 64-bit module processed with warnings somewhere in the tree.
    /// </summary>
    DuplicateModule64Warning,

    /// <summary>
    /// Forwarded module is missing.
    /// </summary>
    MissingForwardedModule,

    /// <summary>
    /// Forwarded module is invalid.
    /// </summary>
    InvalidForwardedModule,

    /// <summary>
    /// This is forwarded module.
    /// </summary>
    ForwardedModule,

    /// <summary>
    /// This is forwarded module processed somewhere in the tree.
    /// </summary>
    ForwardedModuleDuplicate,

    /// <summary>
    /// This is forwarded module with warnings.
    /// </summary>
    ForwardedModuleWarning,

    /// <summary>
    /// This is duplicate forwarded module with warnings.
    /// </summary>
    ForwardedModuleDuplicateWarning,

    /// <summary>
    /// This is 64-bit forwarded module.
    /// </summary>
    ForwardedModule64,

    /// <summary>
    /// This is 64-bit forwarded module processed somewhere in the tree.
    /// </summary>
    ForwardedModule64Duplicate,

    /// <summary>
    /// This is 64-bit forwarded module with warnings.
    /// </summary>
    ForwardedModule64Warning,

    /// <summary>
    /// This is 64-bit duplicate forwarded module with warnings.
    /// </summary>
    ForwardedModule64DuplicateWarning,

    /// <summary>
    /// Delay-load module is missing.
    /// </summary>
    MissingDelayLoadModule,

    /// <summary>
    /// Delay-load module is invalid.
    /// </summary>
    InvalidDelayLoadModule,

    /// <summary>
    /// This is a delay-load module.
    /// </summary>
    DelayLoadModule,

    /// <summary>
    /// Delay-load module processed somewhere in the tree.
    /// </summary>
    DelayLoadModuleDuplicate,

    /// <summary>
    /// Delay-load module with warnings.
    /// </summary>
    DelayLoadModuleWarning,

    /// <summary>
    /// Delay-load module processed somewhere in the tree with warnings.
    /// </summary>
    DelayLoadModuleDuplicateWarning,

    /// <summary>
    /// This is delay-load module 64-bit.
    /// </summary>
    DelayLoadModule64,

    /// <summary>
    /// Delay-load 64-bit module processed somewhere in the tree.
    /// </summary>
    DelayLoadModule64Duplicate,

    /// <summary>
    /// Delay-load 64-bit module with warnings.
    /// </summary>
    DelayLoadModule64Warning,

    /// <summary>
    /// Delay-load 64-bit module processed somewhere in the tree with warnings.
    /// </summary>
    DelayLoadModule64DuplicateWarning,

    /// <summary>
    /// Dynamic module that is missing.
    /// </summary>
    MissingDynamicModule,

    /// <summary>
    /// Dynamic module that is invalid.
    /// </summary>
    InvalidDynamicModule,

    /// <summary>
    /// Dynamic module.
    /// </summary>
    NormalDynamicModule,

    /// <summary>
    /// Duplicate module processed somewhere in the tree.
    /// </summary>
    DuplicateDynamicModule,

    /// <summary>
    /// Dynamic module with warnings.
    /// </summary>
    WarningDynamicModule,

    /// <summary>
    /// Duplicate dynamic module with warnings.
    /// </summary>
    DuplicateDynamicModuleWarning,

    /// <summary>
    /// Dynamic module 64-bit.
    /// </summary>
    NormalDynamicModule64,

    /// <summary>
    /// Duplicate 64-bit module processed somewhere in the tree.
    /// </summary>
    DuplicateDynamicModule64,

    /// <summary>
    /// Dynamic 64-bit module with warnings.
    /// </summary>
    WarningDynamicModule64,

    /// <summary>
    /// Duplicate dynamic 64-bit module with warnings.
    /// </summary>
    DuplicateDynamicModule64Warning,

    /// <summary>
    /// Dynamic module mapped as image or datafile.
    /// </summary>
    DynamicMappedModuleNoExec,

    /// <summary>
    /// Dynamic 64-bit module mapped as image or datafile.
    /// </summary>
    DynamicMappedModule64NoExec,

    /// <summary>
    /// Dynamic module mapped as image or datafile with warnings.
    /// </summary>
    DynamicMappedModuleNoExecWarning,
    /// <summary>
    /// Dynamic 64-bit module mapped as image or datafile with warnings.
    /// </summary>
    DynamicMappedModule64NoExecWarning
}

public enum ModuleIconCompactType
{
    /// <summary>
    /// Missing module.
    /// </summary>
    MissingModule = 0,

    /// <summary>
    /// Missing delay-load module.
    /// </summary>
    DelayLoadMissing,

    /// <summary>
    /// Missing dynamic module.
    /// </summary>
    DynamicMissing,

    /// <summary>
    /// Invalid module.
    /// </summary>
    Invalid,

    /// <summary>
    /// Invalid delay-load module.
    /// </summary>
    DelayLoadInvalid,

    /// <summary>
    /// Invalid dynamic module.
    /// </summary>
    DynamicInvalid,

    /// <summary>
    /// Warning for module.
    /// </summary>
    WarningModule,

    /// <summary>
    /// Warning for module 64-bit.
    /// </summary>
    WarningModule64,

    /// <summary>
    /// Warning for delay-load module.
    /// </summary>
    DelayLoadModuleWarning,

    /// <summary>
    /// Warning for delay-load module 64-bit.
    /// </summary>
    DelayLoadModule64Warning,

    /// <summary>
    /// Warning for dynamic load module.
    /// </summary>
    DynamicModuleWarning,

    /// <summary>
    /// Warning for dynamic load module 64-bit.
    /// </summary>
    DynamicModule64Warning,

    /// <summary>
    /// Warning for module loaded with 
    /// DONT_RESOLVE_DLL_REFERENCES and/or the LOAD_LIBRARY_AS_DATAFILE flag.
    /// </summary>
    WarningMappedNoExecImage,

    /// <summary>
    /// Warning for module 64-bit loaded with 
    /// DONT_RESOLVE_DLL_REFERENCES and/or the LOAD_LIBRARY_AS_DATAFILE flag.
    /// </summary>
    WarningMappedNoExecImage64,

    /// <summary>
    /// Normal module with no errors. 
    /// </summary>
    NormalModule,

    /// <summary>
    /// Normal 64-bit module with no errors.
    /// </summary>
    NormalModule64,

    /// <summary>
    /// Delay-load module.
    /// </summary>
    DelayLoadModule,

    /// <summary>
    /// Delay-load module 64-bit.
    /// </summary>
    DelayLoadModule64,

    /// <summary>
    /// Dynamic module.
    /// </summary>
    DynamicModule,

    /// <summary>
    /// Dynamic module 64-bit.
    /// </summary>
    DynamicModule64,

    /// <summary>
    /// The module mapped as image or datafile.
    /// </summary>
    MappedModuleNoExec,

    /// <summary>
    /// The 64-bit module mapped as image or datafile.
    /// </summary>
    MappedModule64NoExec
}
public enum LogEventType
{
    StartMessage,
    FileOpenSession,
    FileOpenSessionError,
    FileSessionSave,
    FileSessionSaveError,
    CoreServerStartOK,
    CoreServerStartError,
    CoreServerReceiveError,
    CoreServerSendError,
    CoreServerDeserializeError,
    ModuleProcessingError,
    ModuleNotFound,
    ModuleNotFoundExtApiSet,
    DelayLoadModuleNotFound,
    DelayLoadModuleNotFoundExtApiSet,
    ModuleExportsError,
    ModuleMachineMismatch,
    ModuleLogFromSession,
    ModuleOpenHardError,
    MaxEventType
}

public enum FileViewUpdateAction
{
    TreeViewAutoExpandsChange,
    FunctionsUndecorateChange,
    ModulesTreeAndListChange
}

/// <summary>
/// Built-in file extensions declaration.
/// </summary>
static class InternalFileHandledExtensions
{
    public static List<PropertyElement> ExtensionList { get; } =
    [
        new PropertyElement("exe", "Application"),
        new PropertyElement("com", "Application"),
        new PropertyElement("dll", "Dynamic Link Library"),
        new PropertyElement("sys", "System File"),
        new PropertyElement("drv", "Driver File"),
        new PropertyElement("efi", "UEFI Runtime Module"),
        new PropertyElement("cpl", "Control Panel File"),
        new PropertyElement("bpl", "Borland Package Library"),
        new PropertyElement("tlb", "Type Library"),
        new PropertyElement("scr", "Screensaver Executable"),
        new PropertyElement("ocx", "ActiveX Control"),
        new PropertyElement("ax", "DirectShow Filter"),
        new PropertyElement("acm", "Audio Compression Manager Codec")
    ];

}

public enum SearchOrderType : uint
{
    WinSXS = 0,
    KnownDlls,
    ApplicationDirectory,
    System32Directory,
    SystemDirectory,
    WindowsDirectory,
    EnvironmentPathDirectories,
    SystemDriversDirectory,
    UserDefinedDirectory,
    None = 0xfff
}

/// <summary>
/// SearchOrderTypes extension to return description of levels.
/// </summary>
public static class SearchOrderTypesExtension
{
    public static string ToDescription(this SearchOrderType searchOrder)
    {
        return searchOrder switch
        {
            SearchOrderType.WinSXS => "Side-by-side components",
            SearchOrderType.KnownDlls => "The system's KnownDlls list",
            SearchOrderType.WindowsDirectory => "The system's root OS directory",
            SearchOrderType.ApplicationDirectory => "The application directory",
            SearchOrderType.System32Directory => "The system directory",
            SearchOrderType.SystemDirectory => "The 16-bit system directory",
            SearchOrderType.EnvironmentPathDirectories => "The system's \"PATH\" environment variable directories",
            SearchOrderType.UserDefinedDirectory => "The user defined directory",
            _ => searchOrder.ToString()
        };
    }
}
