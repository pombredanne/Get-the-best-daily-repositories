/*******************************************************************************
*
*  (C) COPYRIGHT AUTHORS, 2024
*
*  TITLE:       PROGRAM.CS
*
*  VERSION:     1.00
*
*  DATE:        03 Aug 2024
*
* THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF
* ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED
* TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
* PARTICULAR PURPOSE.
*
*******************************************************************************/
namespace WinDepends;

internal static class Program
{

    static void ExceptionHandler(object sender, UnhandledExceptionEventArgs args)
    {
        Exception ex = (Exception)args.ExceptionObject;
        MessageBox.Show($"Exception: {ex}, please report to developers",
            CConsts.ProgramName, MessageBoxButtons.OK, MessageBoxIcon.Error);
    }

    /// <summary>
    ///  The main entry point for the application.
    /// </summary>
    [STAThread]
    static void Main()
    {
        AppDomain currentDomain = AppDomain.CurrentDomain;
        currentDomain.UnhandledException += new UnhandledExceptionEventHandler(ExceptionHandler);

        ApplicationConfiguration.Initialize();
        Application.SetHighDpiMode(HighDpiMode.SystemAware);
        Application.EnableVisualStyles();
        Application.Run(new MainForm());
    }
}
